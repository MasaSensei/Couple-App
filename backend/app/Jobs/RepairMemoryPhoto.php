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
use RuntimeException;
use Throwable;

/**
 * Restores one bad copy from the other copy, byte-for-byte (ciphertext is never
 * changed or decrypted). The source is re-verified against the DB checksum
 * immediately before use, and the restored copy is re-verified before the photo
 * is marked healthy. Both buckets are versioned, so the bad bytes that get
 * replaced remain as a noncurrent version for investigation.
 */
class RepairMemoryPhoto implements ShouldQueue, ShouldBeUnique
{
    use Queueable;

    public int $tries = 3;

    // Below the queue's retry_after (90s).
    public int $timeout = 75;

    public int $uniqueFor = 3600;

    public function __construct(
        public readonly int $photoId,
        public readonly string $actor = 'system',
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
        // Shared with BackupMemoryPhoto: nothing else writes this photo's objects meanwhile.
        return [
            (new WithoutOverlapping('memory-photo:'.$this->photoId))
                ->shared()
                ->releaseAfter(60)
                ->expireAfter($this->timeout + 60),
        ];
    }

    public function handle(): void
    {
        $photo = MemoryPhoto::withTrashed()->find($this->photoId);

        if ($photo === null || $photo->status !== 'verified' || blank($photo->checksum)) {
            return;
        }

        $stores = ['primary' => app(PhotoStorage::class), 'backup' => app('photos.backup')];

        // Fresh evidence, not the state recorded by the last check. Unreachable stores throw.
        $state = array_map(fn (PhotoStorage $store) => $this->check($store, $photo), $stores);

        // The backup is only expected to exist once its job verified it.
        $backupExpected = $photo->backup_status === 'verified';

        if ($state['primary'] === 'ok' && ($state['backup'] === 'ok' || ! $backupExpected)) {
            $this->finish($photo, $state, 'skipped', 'All expected copies are healthy.');

            return;
        }

        $target = $state['primary'] === 'ok' ? 'backup' : 'primary';
        $source = $target === 'primary' ? 'backup' : 'primary';

        if ($state[$source] !== 'ok') {
            // Never restore from an unverified copy, and never claim success.
            $this->finish($photo, $state, 'failed', "No verified copy: primary {$state['primary']}, backup {$state['backup']}.");

            Log::critical('Photo has no verified copy; operator intervention needed.', [
                'photo_id' => $photo->id,
                'primary' => $state['primary'],
                'backup' => $state['backup'],
            ]);

            return;
        }

        $stores[$target]->putObject($photo->storage_key, $stores[$source]->readStream($photo->storage_key));

        $state[$target] = $this->check($stores[$target], $photo);

        if ($state[$target] !== 'ok') {
            // Retried; the source copy is untouched.
            throw new RuntimeException("Restored {$target} failed verification ({$state[$target]}).");
        }

        $this->finish($photo, $state, 'succeeded', "Restored {$target} from {$source}.");

        // A backup that gave up because the primary was bad can run again now.
        // Not dispatched here: this job holds the photo lock; the pending sweeper picks it up.
        if ($target === 'primary' && $photo->backup_status === 'failed') {
            $photo->forceFill(['backup_status' => 'pending', 'backup_error' => null])->save();
        }
    }

    public function failed(?Throwable $exception): void
    {
        $photo = MemoryPhoto::withTrashed()->find($this->photoId);

        $photo?->forceFill(['repair_status' => 'failed'])->save();

        PhotoStorageAudit::record($this->photoId, 'repair', 'failed', $this->actor,
            $exception ? class_basename($exception).': '.$exception->getMessage() : null);

        Log::critical('Photo repair failed after retries.', [
            'photo_id' => $this->photoId,
            'error' => $exception ? $exception::class : null,
        ]);
    }

    private function check(PhotoStorage $store, MemoryPhoto $photo): string
    {
        return $store->checkIntegrity($photo->storage_key, $photo->checksum, $photo->encrypted_size);
    }

    /** @param array{primary: string, backup: string} $state */
    private function finish(MemoryPhoto $photo, array $state, string $result, string $detail): void
    {
        $photo->forceFill([
            'primary_integrity' => $state['primary'],
            // Do not record a verdict on a backup copy that is not supposed to exist yet.
            'backup_integrity' => $photo->backup_status === 'verified' ? $state['backup'] : $photo->backup_integrity,
            'integrity_checked_at' => now(),
            'repair_status' => $result === 'failed' ? 'failed' : null,
        ])->save();

        PhotoStorageAudit::record($photo->id, 'repair', $result, $this->actor, $detail);
    }
}
