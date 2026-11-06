<?php

namespace App\Services\Storage;

use App\Models\DatabaseBackup;
use App\Models\MemoryPhoto;
use App\Models\PhotoStorageAudit;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Throwable;

/**
 * Operational metrics for Filament and storage:alerts. Metadata only: no
 * keys, no plaintext, no object paths or signed URLs.
 */
class StorageHealthService
{
    /** Same thresholds as reliability.md §6. */
    public const BACKUP_PENDING_ALERT_MINUTES = 60;

    public const QUEUE_BACKLOG_ALERT = 500;

    public function metrics(): array
    {
        $live = MemoryPhoto::query()->whereNull('primary_purged_at');
        $counts = MemoryPhoto::protectionCounts(MemoryPhoto::query());
        $count = fn (string $status) => $counts[$status] ?? 0;

        $lastBackup = DatabaseBackup::latestSucceeded();
        $lastRestoreCheck = DatabaseBackup::whereNotNull('restore_checked_at')->latest('restore_checked_at')->first();

        return [
            'photos_total' => array_sum($counts) - $count('deleted'),
            'protected' => $count('protected'),
            'backup_pending' => $count('backup_pending'),
            'backup_pending_stale' => (clone $live)->whereNull('deleted_at')->where('status', 'verified')->where('backup_status', 'pending')
                ->where('updated_at', '<=', now()->subMinutes(self::BACKUP_PENDING_ALERT_MINUTES))->count(),
            'degraded' => $count('degraded'),
            'restoring' => $count('restoring'),
            'pending_upload' => $count('pending_upload'),
            'integrity_mismatch' => (clone $live)->where('status', 'verified')->where(fn ($query) => $query
                ->where('primary_integrity', 'mismatch')->orWhere('backup_integrity', 'mismatch'))->count(),
            'needs_operator' => (clone $live)->where('repair_status', 'failed')->count(),
            'failed_uploads' => $count('failed'),
            'in_trash' => MemoryPhoto::onlyTrashed()->whereNull('primary_purged_at')->count(),
            'repairs_succeeded_7d' => $this->auditCount('repair', 'succeeded'),
            'repairs_failed_7d' => $this->auditCount('repair', 'failed'),
            'last_integrity_check_at' => MemoryPhoto::max('integrity_checked_at'),
            'last_backup_verified_at' => MemoryPhoto::max('backup_verified_at'),
            'ciphertext_bytes' => (int) (clone $live)->where('status', 'verified')->sum('encrypted_size'),
            'backup_bytes' => (int) (clone $live)->where('backup_status', 'verified')->sum('encrypted_size'),
            'db_backup_at' => $lastBackup?->finished_at,
            'db_backup_age_hours' => $lastBackup ? round($lastBackup->finished_at->diffInMinutes(now()) / 60, 1) : null,
            'db_backup_bytes' => $lastBackup?->size_bytes,
            'db_restore_checked_at' => $lastRestoreCheck?->restore_checked_at,
            'db_restore_result' => $lastRestoreCheck?->restore_result,
            'failed_jobs' => DB::table('failed_jobs')->count(),
            'queue_size' => rescue(fn () => Queue::size(), null, false),
        ];
    }

    /**
     * @return list<array{level: 'critical'|'warning', code: string, message: string}>
     */
    public function alerts(?array $metrics = null): array
    {
        $m = $metrics ?? $this->metrics();
        $alerts = [];

        $add = function (bool $when, string $level, string $code, string $message) use (&$alerts): void {
            if ($when) {
                $alerts[] = compact('level', 'code', 'message');
            }
        };

        $add($m['needs_operator'] > 0, 'critical', 'repair_failed', "{$m['needs_operator']} photo(s) have no verified copy and need an operator.");
        $add($m['integrity_mismatch'] > 0, 'critical', 'integrity_mismatch', "{$m['integrity_mismatch']} photo(s) failed checksum verification.");
        $add($m['backup_pending_stale'] > 0, 'warning', 'backup_pending', "{$m['backup_pending_stale']} backup(s) pending for more than ".self::BACKUP_PENDING_ALERT_MINUTES.' min.');
        $add($m['degraded'] > 0, 'warning', 'degraded', "{$m['degraded']} photo(s) are degraded (one copy or metadata missing).");
        $add($m['db_backup_at'] === null, 'critical', 'db_backup_missing', 'No successful database backup exists.');
        $add($m['db_backup_age_hours'] !== null && $m['db_backup_age_hours'] > config('backup.max_age_hours'), 'critical', 'db_backup_stale',
            "Last database backup is {$m['db_backup_age_hours']} h old.");
        $add($m['db_restore_result'] === 'failed', 'critical', 'db_restore_failed', 'The last database restore check failed.');
        $add($m['db_backup_at'] !== null && $m['db_restore_checked_at'] === null, 'warning', 'db_restore_untested', 'No database backup has been restore-tested yet.');
        $add($m['failed_jobs'] > 0, 'warning', 'failed_jobs', "{$m['failed_jobs']} failed queue job(s).");
        $add(($m['queue_size'] ?? 0) > self::QUEUE_BACKLOG_ALERT, 'warning', 'queue_backlog', "Queue backlog: {$m['queue_size']} job(s).");

        foreach (['primary' => app(PhotoStorage::class), 'backup' => app('photos.backup')] as $name => $store) {
            try {
                $store->listKeys('__health__/');
            } catch (Throwable) {
                $alerts[] = ['level' => 'critical', 'code' => "{$name}_unreachable", 'message' => "The {$name} photo store is unreachable."];
            }
        }

        return $alerts;
    }

    private function auditCount(string $action, string $result): int
    {
        return PhotoStorageAudit::where('action', $action)->where('result', $result)
            ->where('created_at', '>=', now()->subDays(7))->count();
    }
}
