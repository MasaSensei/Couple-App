<?php

namespace App\Filament\Widgets;

use App\Services\Storage\StorageHealthService;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Illuminate\Support\Number;

/** Operational storage status. Counts and timestamps only. */
class StorageHealthOverview extends StatsOverviewWidget
{
    protected static ?int $sort = 1;

    protected ?string $heading = 'Storage & backups';

    protected ?string $description = 'Photos count as protected only after their backup copy is verified.';

    protected ?string $pollingInterval = '60s';

    public static function canView(): bool
    {
        return auth()->user()?->is_admin === true;
    }

    protected function getStats(): array
    {
        $health = app(StorageHealthService::class);
        $m = $health->metrics();
        $alerts = $health->alerts($m);
        $critical = collect($alerts)->where('level', 'critical')->count();

        return [
            Stat::make('Alerts', count($alerts))
                ->description(collect($alerts)->pluck('message')->first() ?? 'No active alerts')
                ->color($critical > 0 ? 'danger' : (count($alerts) > 0 ? 'warning' : 'success')),
            Stat::make('Protected photos', "{$m['protected']} / {$m['photos_total']}")
                ->description("{$m['backup_pending']} backing up · {$m['restoring']} restoring")
                ->color($m['protected'] === $m['photos_total'] ? 'success' : 'warning'),
            Stat::make('Degraded', $m['degraded'])
                ->description("{$m['integrity_mismatch']} checksum mismatch · {$m['needs_operator']} need operator")
                ->color($m['degraded'] + $m['needs_operator'] > 0 ? 'danger' : 'success'),
            Stat::make('Repairs (7 days)', "{$m['repairs_succeeded_7d']} ok / {$m['repairs_failed_7d']} failed")
                ->description('Last integrity check: '.($m['last_integrity_check_at'] ?? 'never'))
                ->color($m['repairs_failed_7d'] > 0 ? 'danger' : 'gray'),
            Stat::make('Database backup', $m['db_backup_age_hours'] === null ? 'none' : "{$m['db_backup_age_hours']} h ago")
                ->description('Restore check: '.($m['db_restore_result'] ?? 'never').
                    ($m['db_restore_checked_at'] ? ' ('.$m['db_restore_checked_at']->diffForHumans().')' : ''))
                ->color($m['db_backup_age_hours'] === null || $m['db_backup_age_hours'] > config('backup.max_age_hours')
                    || $m['db_restore_result'] !== 'passed' ? 'danger' : 'success'),
            Stat::make('Storage used', Number::fileSize($m['ciphertext_bytes'] + $m['backup_bytes']))
                ->description('Primary '.Number::fileSize($m['ciphertext_bytes']).' · backup '.Number::fileSize($m['backup_bytes'])
                    .' · DB dump '.Number::fileSize((int) $m['db_backup_bytes'])),
            Stat::make('Queue', $m['queue_size'] ?? 'n/a')
                ->description("{$m['failed_jobs']} failed job(s) · {$m['in_trash']} photo(s) in trash")
                ->color($m['failed_jobs'] > 0 ? 'warning' : 'gray'),
        ];
    }
}
