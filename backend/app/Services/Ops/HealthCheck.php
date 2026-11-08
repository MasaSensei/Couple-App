<?php

namespace App\Services\Ops;

use App\Services\Storage\FlysystemPhotoStorage;
use App\Services\Storage\PhotoStorage;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\Storage;
use League\Flysystem\AwsS3V3\AwsS3V3Adapter;
use Throwable;

/**
 * Readiness of every dependency the API needs. Used by GET /api/v1/health/ready
 * (load balancer + external uptime monitor) and by `ops:alerts`.
 */
class HealthCheck
{
    public function __construct(private readonly Heartbeat $heartbeat) {}

    /** @return array{status: 'ok'|'fail', checks: array<string, array{ok: bool, ms: int, detail?: string}>} */
    public function run(): array
    {
        $checks = [
            'database' => $this->time(fn () => DB::select('select 1')),
        ];

        if ($this->usesRedis()) {
            $checks['redis'] = $this->time(fn () => Redis::connection()->ping());
        }

        $checks['storage_primary'] = $this->time(fn () => $this->probeStore('photos_primary', PhotoStorage::class));
        $checks['storage_backup'] = $this->time(fn () => $this->probeStore('photos_backup', 'photos.backup'));

        foreach (Heartbeat::COMPONENTS as $component) {
            if ($component === 'queue' && config('queue.default') === 'sync') {
                continue;
            }

            $checks[$component] = $this->time(function () use ($component): void {
                if ($this->heartbeat->isStale($component)) {
                    $age = $this->heartbeat->age($component);

                    throw new \RuntimeException($age === null ? 'never ran' : "last beat {$age}s ago");
                }
            }, exposeMessage: true);
        }

        $ok = collect($checks)->every(fn (array $check) => $check['ok']);

        return ['status' => $ok ? 'ok' : 'fail', 'checks' => $checks];
    }

    /**
     * Readiness must answer within a load balancer's timeout, so the store is
     * probed with its own short timeouts and no SDK retries (the app's disks
     * retry 3× with a 5 s connect timeout, which made a down store take >20 s).
     * Tests and dev overrides that bind a fake store are probed through it.
     */
    private function probeStore(string $disk, string $binding): void
    {
        $store = app($binding);

        // Fakes / test doubles (Storage::fake, mocked bindings) are probed directly.
        if (! $store instanceof FlysystemPhotoStorage || ! Storage::disk($disk)->getAdapter() instanceof AwsS3V3Adapter) {
            $store->listKeys('__health__/');

            return;
        }

        Storage::build([
            ...config("filesystems.disks.{$disk}"),
            'http' => ['connect_timeout' => 2, 'timeout' => 3],
            'retries' => 0,
        ])->files('__health__/');
    }

    private function usesRedis(): bool
    {
        return in_array('redis', [config('queue.default'), config('cache.default'), config('session.driver')], true);
    }

    /** @return array{ok: bool, ms: int, detail?: string} */
    private function time(callable $probe, bool $exposeMessage = false): array
    {
        $start = hrtime(true);

        try {
            $probe();

            return ['ok' => true, 'ms' => $this->elapsed($start)];
        } catch (Throwable $exception) {
            // Exception class only: connection errors can contain hostnames/credentials.
            return [
                'ok' => false,
                'ms' => $this->elapsed($start),
                'detail' => $exposeMessage ? $exception->getMessage() : class_basename($exception),
            ];
        }
    }

    private function elapsed(int $start): int
    {
        return (int) round((hrtime(true) - $start) / 1e6);
    }
}
