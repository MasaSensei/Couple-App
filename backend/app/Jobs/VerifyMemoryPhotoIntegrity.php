<?php

namespace App\Jobs;

use App\Models\MemoryPhoto;
use App\Services\Storage\PhotoStorage;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Log;

/**
 * Scheduled re-hash of every copy against the trusted DB checksum. Detection
 * only: it never writes, moves or deletes an object. Repair is a separate job.
 */
class VerifyMemoryPhotoIntegrity implements ShouldQueue, ShouldBeUnique
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

    public function handle(): void
    {
        // Trashed photos are checked too: they must still be restorable during retention.
        $photo = MemoryPhoto::withTrashed()->find($this->photoId);

        // A purged primary is gone on purpose; reporting it as missing would trigger a repair.
        if ($photo === null || $photo->status !== 'verified' || blank($photo->checksum) || $photo->isPurged()) {
            return;
        }

        // Unreachable store: throws before anything is recorded, then retried.
        $primary = app(PhotoStorage::class)
            ->checkIntegrity($photo->storage_key, $photo->checksum, $photo->encrypted_size);

        // A backup still being written is not checked; its job verifies it.
        $backup = $photo->backup_status === 'verified'
            ? app('photos.backup')->checkIntegrity($photo->storage_key, $photo->checksum, $photo->encrypted_size)
            : null;

        $photo->forceFill([
            'primary_integrity' => $primary,
            'backup_integrity' => $backup,
            'integrity_checked_at' => now(),
        ])->save();

        if ($primary !== 'ok' || ($backup !== null && $backup !== 'ok')) {
            // Alert hook: STEP 11 routes this to operators.
            Log::warning('Photo integrity problem detected.', [
                'photo_id' => $photo->id,
                'primary' => $primary,
                'backup' => $backup,
            ]);

            // Self-heal from the other copy if it is still good (RepairMemoryPhoto re-verifies it).
            if ($photo->repair_status !== 'failed') {
                $photo->forceFill(['repair_status' => 'pending'])->save();
                RepairMemoryPhoto::dispatch($photo->id);
            }
        }
    }
}
