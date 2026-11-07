<?php

namespace App\Services\Ops;

use App\Models\CoupleSubscription;
use App\Models\PaymentWebhookEvent;
use App\Services\Storage\StorageHealthService;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Every alert that needs a human: storage/backup (StorageHealthService),
 * infrastructure (HealthCheck) and billing consistency. Each alert names the
 * runbook section that says what to do (docs/operations/runbooks.md).
 */
class OpsAlerts
{
    public function __construct(
        private readonly StorageHealthService $storage,
        private readonly HealthCheck $health,
    ) {}

    /** @return list<array{level: string, code: string, message: string}> */
    public function current(): array
    {
        $alerts = $this->guard('storage', fn () => $this->storage->alerts());

        $health = $this->guard('health', fn () => [$this->health->run()]);
        foreach (($health[0]['checks'] ?? []) as $name => $check) {
            // Storage reachability is already reported by StorageHealthService.
            if (! $check['ok'] && ! str_starts_with($name, 'storage_')) {
                $alerts[] = ['level' => 'critical', 'code' => "{$name}_down", 'message' => "{$name} is not healthy: ".($check['detail'] ?? 'unknown').'.'];
            }
        }

        return [...$alerts, ...$this->guard('billing', fn () => $this->billing())];
    }

    /**
     * Evaluate and route alerts to the `alerts` log channel. Re-sends an
     * active alert at most every 6 h. Dedupe uses the cache, but a cache
     * (Redis) outage must not silence alerts: then every alert is sent.
     *
     * @return list<array{level: string, code: string, message: string}>
     */
    public function dispatch(): array
    {
        $alerts = collect($this->current())->keyBy('code');
        $previous = $this->cache(fn () => Cache::get('ops:alerts:active', []), []);

        foreach ($alerts as $code => $alert) {
            $fresh = $this->cache(fn () => Cache::add("ops:alerts:sent:{$code}", true, now()->addHours(6)), true);

            if ($fresh) {
                Log::channel('alerts')->{$alert['level']}($alert['message'], ['code' => $code, 'runbook' => "docs/operations/runbooks.md#{$code}"]);
            }
        }

        foreach (array_diff($previous, $alerts->keys()->all()) as $code) {
            $this->cache(fn () => Cache::forget("ops:alerts:sent:{$code}"), null);
            Log::channel('alerts')->notice("Resolved: {$code}", ['code' => $code]);
        }

        $this->cache(fn () => Cache::forever('ops:alerts:active', $alerts->keys()->all()), null);

        return $alerts->values()->all();
    }

    /** @return list<array{level: string, code: string, message: string}> */
    private function billing(): array
    {
        $alerts = [];

        $stuck = PaymentWebhookEvent::query()
            ->whereIn('status', ['received', 'failed', 'processing'])
            ->where('created_at', '<=', now()->subMinutes(config('observability.webhook_stuck_minutes')))
            ->count();
        if ($stuck > 0) {
            $alerts[] = ['level' => 'warning', 'code' => 'webhook_stuck', 'message' => "{$stuck} payment webhook(s) not processed after ".config('observability.webhook_stuck_minutes').' min.'];
        }

        // Active but past period end + leeway: the sweep or the provider is not keeping state in sync.
        $inconsistent = CoupleSubscription::query()
            ->where('status', 'active')
            ->whereNotNull('current_period_end')
            ->where('current_period_end', '<', now()->subHours(config('billing.renewal_leeway_hours') + 2))
            ->count();
        if ($inconsistent > 0) {
            $alerts[] = ['level' => 'warning', 'code' => 'subscription_state_inconsistent', 'message' => "{$inconsistent} subscription(s) are active past their period end."];
        }

        return $alerts;
    }

    /** One failing source must not hide the others; its failure becomes an alert. */
    private function guard(string $source, callable $collect): array
    {
        try {
            return $collect();
        } catch (Throwable $exception) {
            report($exception);

            return $source === 'health' ? [] : [[
                'level' => 'critical',
                'code' => "{$source}_check_failed",
                'message' => "Could not evaluate {$source} alerts (".class_basename($exception).').',
            ]];
        }
    }

    private function cache(callable $operation, mixed $fallback): mixed
    {
        try {
            return $operation();
        } catch (Throwable) {
            return $fallback;
        }
    }
}
