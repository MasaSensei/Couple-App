<?php

namespace App\Services\Ops;

use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Throwable;

/** Records that a background process is alive and pings its external dead-man's switch. */
class Heartbeat
{
    public const COMPONENTS = ['scheduler', 'queue'];

    public function beat(string $name): void
    {
        DB::table('ops_heartbeats')->upsert(
            [['name' => $name, 'beat_at' => now(), 'host' => gethostname() ?: null]],
            ['name'],
            ['beat_at', 'host'],
        );

        $url = config("observability.heartbeat_urls.{$name}");

        if (filled($url)) {
            try {
                Http::timeout(5)->retry(2, 500, throw: false)->get($url);
            } catch (Throwable $exception) {
                // The external monitor alerts on the missing ping; nothing else to do here.
                report($exception);
            }
        }
    }

    public function lastBeat(string $name): ?Carbon
    {
        $value = DB::table('ops_heartbeats')->where('name', $name)->value('beat_at');

        return $value === null ? null : Carbon::parse($value);
    }

    /** Seconds since the last beat, or null when it never ran. */
    public function age(string $name): ?int
    {
        $last = $this->lastBeat($name);

        return $last === null ? null : (int) $last->diffInSeconds(now(), true);
    }

    public function isStale(string $name): bool
    {
        $age = $this->age($name);

        return $age === null || $age > config('observability.heartbeat_stale_seconds');
    }
}
