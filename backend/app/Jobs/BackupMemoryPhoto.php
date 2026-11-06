<?php

namespace App\Jobs;

use App\Models\MemoryPhoto;
use App\Services\Storage\PhotoStorage;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Queue\Middleware\WithoutOverlapping;
use Illuminate\Support\Facades\Log;
use RuntimeException;
use Throwable;

/**
 * Copies a photo's ciphertext byte-for-byte to the backup store and verifies it
 * against the trusted DB checksum. Never decrypts. Safe to run any number of
 * times: an already-verified backup is recognised, and the backup bucket is
 * versioned so a rewrite never destroys an earlier copy.
 */
class BackupMemoryPhoto implements ShouldQueue, ShouldBeUnique
{
    use Queueable;

    public int $tries = 5;

    // Must stay below the queue's retry_after (90s) or a slow copy gets re-run in parallel.
    public int $timeout = 75;

    // One queued job per photo, held through backoff, so the pending sweeper
    // cannot stack extra retry budgets on top of $tries. Expires if the job is lost.
    public int $uniqueFor = 7200;

    public function __construct(
        public readonly int $photoId,
    ) {}

    public function uniqueId(): string
    {
        return (string) $this->photoId;
    }

    public function backoff(): array
    {
        return [60, 300, 900, 3600];
    }

    public function middleware(): array
    {
        // Two workers never copy the same photo at once; a duplicate is dropped
        // because the running copy does the same work.
        return [
            (new WithoutOverlapping('memory-photo:'.$this->photoId))
                ->shared() // also held by RepairMemoryPhoto
                ->dontRelease()
                ->expireAfter($this->timeout + 60),
        ];
    }

    public function handle(): void
    {
        // Deleted photos are still backed up: retention, not this job, decides their fate.
        $photo = MemoryPhoto::withTrashed()->find($this->photoId);

        if ($photo === null || $photo->status !== 'verified' || $photo->backup_status === 'verified' || $photo->isPurged()) {
            return;
        }

        $primary = app(PhotoStorage::class);
        $backup = app('photos.backup');

        try {
            // Crash after copy but before the DB update: the copy is already there.
            if (! $this->backupMatches($backup, $photo)) {
                // Never propagate a corrupt primary into the backup.
                $primaryIntegrity = $primary->checkIntegrity($photo->storage_key, $photo->checksum, $photo->encrypted_size);

                if ($primaryIntegrity !== 'ok') {
                    // Retrying cannot help; repair (STEP 7) has to fix the primary first.
                    $photo->forceFill(['primary_integrity' => $primaryIntegrity, 'repair_status' => 'pending']);
                    $this->markFailed($photo, "Primary {$primaryIntegrity}; not copied.");
                    RepairMemoryPhoto::dispatch($photo->id);
                    $this->fail(new RuntimeException("Primary {$primaryIntegrity}; not copied."));

                    return;
                }

                $backup->putObject($photo->storage_key, $primary->readStream($photo->storage_key));

                if (! $this->backupMatches($backup, $photo)) {
                    throw new RuntimeException('Backup checksum mismatch after copy.');
                }
            }
        } catch (Throwable $exception) {
            $photo->forceFill(['backup_error' => $this->describe($exception)])->save();

            throw $exception;
        }

        // Only flip a row that still describes the bytes we verified.
        MemoryPhoto::withTrashed()
            ->whereKey($photo->id)
            ->where('checksum', $photo->checksum)
            ->update([
                'backup_status' => 'verified',
                'backup_verified_at' => now(),
                'backup_error' => null,
                // Both copies were just hashed against the DB checksum.
                'primary_integrity' => 'ok',
                'backup_integrity' => 'ok',
                'integrity_checked_at' => now(),
            ]);
    }

    public function failed(?Throwable $exception): void
    {
        $photo = MemoryPhoto::withTrashed()->find($this->photoId);

        if ($photo !== null && $photo->backup_status !== 'verified') {
            $this->markFailed($photo, $exception ? $this->describe($exception) : 'Backup failed.');
        }

        // Alert hook: STEP 11 routes this to operators. No keys/paths/credentials logged.
        Log::error('Photo backup failed after retries.', [
            'photo_id' => $this->photoId,
            'error' => $exception ? $exception::class : null,
        ]);
    }

    private function backupMatches(PhotoStorage $backup, MemoryPhoto $photo): bool
    {
        // An unreachable backup throws here, so the attempt is retried rather than rewritten.
        return $backup->checkIntegrity($photo->storage_key, $photo->checksum, $photo->encrypted_size) === 'ok';
    }

    private function markFailed(MemoryPhoto $photo, string $error): void
    {
        $photo->forceFill([
            'backup_status' => 'failed',
            'backup_error' => $error,
        ])->save();
    }

    private function describe(Throwable $exception): string
    {
        // Operator-facing only; storage exceptions carry no credentials.
        return mb_substr(class_basename($exception).': '.$exception->getMessage(), 0, 255);
    }
}
