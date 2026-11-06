<?php

namespace App\Services\Storage;

use App\Jobs\VerifyMemoryPhotoIntegrity;
use App\Models\MemoryPhoto;
use App\Models\PhotoStorageAudit;

/**
 * Compares photo rows with the objects actually present in both stores, e.g.
 * after a database restore (DB and storage snapshots are never taken at the
 * same instant). Report-only: it never deletes an object or a row. The only
 * action is queueing integrity checks, which in turn queue repairs.
 */
class PhotoReconciliationService
{
    /**
     * @return array{
     *     rows: int, primary_objects: int, backup_objects: int,
     *     missing_primary: list<int>, missing_backup: list<int>,
     *     orphan_primary: list<string>, orphan_backup: list<string>,
     *     unfinished_uploads: list<int>, stale_backups: list<int>
     * }
     */
    public function run(string $actor = 'system', bool $queueChecks = true): array
    {
        // Whole bucket: a row may point anywhere, and anything unexplained is worth reporting.
        $primary = array_flip(app(PhotoStorage::class)->listKeys());
        $backup = array_flip(app('photos.backup')->listKeys());

        $report = [
            'rows' => 0,
            'primary_objects' => count($primary),
            'backup_objects' => count($backup),
            'missing_primary' => [],
            'missing_backup' => [],
            'orphan_primary' => [],
            'orphan_backup' => [],
            'unfinished_uploads' => [],
            'stale_backups' => [],
        ];

        $known = [];

        MemoryPhoto::withTrashed()
            ->select(['id', 'storage_key', 'status', 'backup_status', 'primary_purged_at', 'created_at', 'updated_at', 'deleted_at'])
            ->chunkById(1000, function ($photos) use (&$report, &$known, $primary, $backup): void {
                foreach ($photos as $photo) {
                    $report['rows']++;
                    $known[$photo->storage_key] = true;

                    if ($photo->status !== 'verified') {
                        if (! $photo->trashed() && $photo->created_at->lt(now()->subHours(config('photos.abandoned_upload_hours')))) {
                            $report['unfinished_uploads'][] = $photo->id;
                        }

                        continue;
                    }

                    // A purged primary is absent on purpose.
                    if (! $photo->isPurged() && ! isset($primary[$photo->storage_key])) {
                        $report['missing_primary'][] = $photo->id;
                    }

                    if ($photo->backup_status === 'verified' && ! isset($backup[$photo->storage_key])) {
                        $report['missing_backup'][] = $photo->id;
                    }

                    if ($photo->backup_status === 'pending' && $photo->updated_at->lt(now()->subHour())) {
                        $report['stale_backups'][] = $photo->id;
                    }
                }
            });

        // Objects with no row: typically uploads newer than a restored DB backup.
        // Kept untouched; without their row (nonce/mac) they cannot be decrypted anyway.
        $report['orphan_primary'] = array_values(array_diff(array_keys($primary), array_keys($known)));
        $report['orphan_backup'] = array_values(array_diff(array_keys($backup), array_keys($known)));

        if ($queueChecks) {
            // The integrity job re-checks with fresh evidence and queues a repair if needed.
            collect([...$report['missing_primary'], ...$report['missing_backup']])
                ->unique()
                ->each(fn (int $id) => VerifyMemoryPhotoIntegrity::dispatch($id));
        }

        PhotoStorageAudit::record(null, 'reconcile', $this->isClean($report) ? 'succeeded' : 'failed', $actor, $this->summary($report));

        return $report;
    }

    public function isClean(array $report): bool
    {
        foreach (['missing_primary', 'missing_backup', 'orphan_primary', 'orphan_backup', 'unfinished_uploads', 'stale_backups'] as $key) {
            if ($report[$key] !== []) {
                return false;
            }
        }

        return true;
    }

    public function summary(array $report): string
    {
        return collect($report)
            ->map(fn ($value, $key) => $key.'='.(is_array($value) ? count($value) : $value))
            ->implode(' ');
    }
}
