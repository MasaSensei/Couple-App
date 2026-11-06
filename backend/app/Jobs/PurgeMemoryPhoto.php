<?php

namespace App\Jobs;

use App\Models\MemoryPhoto;
use App\Models\PhotoStorageAudit;
use App\Services\Storage\PhotoStorage;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Queue\Middleware\WithoutOverlapping;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Removes a trashed photo's copies once its retention has ended, in two stages:
 *
 *  1. trash_retention_days after deletion: primary object deleted.
 *  2. backup_retention_days after stage 1: backup object deleted, row removed.
 *
 * Deletes are plain S3 deletes. On the versioned buckets they add a delete
 * marker, and the noncurrent bytes expire by the bucket's lifecycle rule, so
 * even a purge that should not have happened can be undone by an operator
 * until then. The app never deletes a specific object version.
 */
class PurgeMemoryPhoto implements ShouldQueue, ShouldBeUnique
{
    use Queueable;

    public int $tries = 3;

    // Below the queue's retry_after (90s).
    public int $timeout = 75;

    public int $uniqueFor = 3600;

    public function __construct(
        public readonly int $photoId,
    ) {}

    public function uniqueId(): string
    {
        return (string) $this->photoId;
    }

    public function backoff(): array
    {
        return [60, 600];
    }

    public function middleware(): array
    {
        // Shared with backup and repair: neither writes this photo's objects meanwhile.
        return [
            (new WithoutOverlapping('memory-photo:'.$this->photoId))
                ->shared()
                ->releaseAfter(60)
                ->expireAfter($this->timeout + 60),
        ];
    }

    public function handle(): void
    {
        $photo = MemoryPhoto::onlyTrashed()->find($this->photoId);

        // Restored, already gone, or never deleted: nothing to purge.
        if ($photo === null) {
            return;
        }

        if (! $photo->isPurged()) {
            $this->purgePrimary($photo);

            return;
        }

        if ($photo->primary_purged_at->copy()->addDays(config('photos.backup_retention_days'))->isFuture()) {
            return;
        }

        // Primary again: a stage-1 delete that failed after its claim must not leave bytes behind.
        app(PhotoStorage::class)->deleteObject($photo->storage_key);
        app('photos.backup')->deleteObject($photo->storage_key);

        PhotoStorageAudit::record($photo->id, 'purge_backup', 'succeeded', 'system');

        // The audit trail survives (memory_photo_id is nulled), the metadata does not.
        $photo->forceFill(['backup_purged_at' => now()])->save();
        $photo->forceDelete();
    }

    public function failed(?Throwable $exception): void
    {
        PhotoStorageAudit::record($this->photoId, 'purge', 'failed', 'system',
            $exception ? class_basename($exception).': '.$exception->getMessage() : null);

        Log::error('Photo purge failed after retries.', [
            'photo_id' => $this->photoId,
            'error' => $exception ? $exception::class : null,
        ]);
    }

    private function purgePrimary(MemoryPhoto $photo): void
    {
        // Claim atomically against a concurrent restore (see MemoryPhotoService::restore).
        $claimed = MemoryPhoto::onlyTrashed()
            ->whereKey($photo->id)
            ->whereNull('primary_purged_at')
            ->where('deleted_at', '<=', now()->subDays(config('photos.trash_retention_days')))
            ->update(['primary_purged_at' => now()]);

        if ($claimed === 0) {
            return;
        }

        // Throws → retried; a re-run reaches stage 2 later, which deletes the primary again.
        app(PhotoStorage::class)->deleteObject($photo->storage_key);

        PhotoStorageAudit::record($photo->id, 'purge_primary', 'succeeded', 'system');
    }
}
