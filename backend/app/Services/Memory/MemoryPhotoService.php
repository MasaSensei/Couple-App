<?php

namespace App\Services\Memory;

use App\Jobs\BackupMemoryPhoto;
use App\Jobs\RepairMemoryPhoto;
use App\Jobs\VerifyMemoryPhotoIntegrity;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\PhotoStorageAudit;
use App\Models\User;
use App\Services\Billing\StorageQuotaExceeded;
use App\Services\Billing\StorageQuotaService;
use App\Services\Storage\PhotoStorage;
use Illuminate\Http\UploadedFile;
use RuntimeException;

class MemoryPhotoService
{

    public function __construct(
        private readonly PhotoStorage $photoStorage,
        private readonly StorageQuotaService $quota,
    ) {}

    public function createUploadSession(
        User $user,
        Memory $memory,
        array $data,
    ): array {
        $storageKey = $this->generateStorageKey(
            $memory,
        );

        // Reserves quota for the ciphertext (or the declared plaintext size
        // until the client sends its encryption metadata). Throws
        // StorageQuotaExceeded before anything is created when full.
        $photo = $this->quota->reserve(
            $memory->couple,
            (int) ($data['encrypted_size'] ?? $data['file_size']),
            null,
            function () use (
                $user,
                $memory,
                $data,
                $storageKey,
            ): MemoryPhoto {
                return MemoryPhoto::create([
                    'memory_id' => $memory->id,
                    'uploaded_by' => $user->id,

                    'storage_key' => $storageKey,

                    // Not stored: file names can reveal private details.
                    'original_filename' => null,

                    'mime_type' =>
                    $data['mime_type'],

                    'file_size' => $data['file_size'],

                    'encryption_version' => $data['encryption_version'] ?? null,
                    'encryption_algorithm' => $data['encryption_algorithm'] ?? null,
                    'key_id' => $data['key_id'] ?? null,
                    'nonce' => $data['nonce'] ?? null,
                    'encrypted_size' => $data['encrypted_size'] ?? null,
                    'checksum' => $data['checksum'] ?? null,

                    'width' => $data['width'] ?? null,

                    'height' =>
                    $data['height'] ?? null,

                    'status' => 'pending',

                    'sort_order' =>
                    $data['sort_order'] ?? 0,
                ]);
            },
        );

        $upload = $this->photoStorage
            ->createUploadSession(
                $storageKey,
                [
                    'mime_type' => $photo->mime_type,
                    'file_size' => $photo->file_size,
                ],
            );

        return [
            'photo' => $photo,
            'upload' => $upload,
        ];
    }

    public function updateEncryptionMetadata(
        MemoryPhoto $photo,
        array $data,
    ): MemoryPhoto {
        if ($photo->status !== 'pending') {
            throw new RuntimeException(
                'Encryption metadata can only be updated while the photo is pending.',
            );
        }

        // The key must be one this couple has already established on its devices.
        if (! $photo->memory->couple->keyPackages()->where('key_id', $data['key_id'])->exists()) {
            throw new RuntimeException('Unknown encryption key.');
        }

        $this->quota->reserve($photo->memory->couple, (int) $data['encrypted_size'], $photo->id, fn () => $photo->update([
            'encryption_version' => $data['encryption_version'],
            'encryption_algorithm' => $data['encryption_algorithm'],
            'key_id' => $data['key_id'],
            'nonce' => $data['nonce'],
            'encrypted_size' => $data['encrypted_size'],
            'checksum' => strtolower($data['checksum']),
            'mac' => $data['mac'],
        ]));

        return $photo->refresh();
    }

    public function complete(
        MemoryPhoto $photo,
    ): MemoryPhoto {

        if (! in_array($photo->status, ['uploading'], true)) {
            throw new RuntimeException(
                'Photo must be uploaded before verification.',
            );
        }

        // Authoritative check on the declared ciphertext size, which
        // verifyObject() below confirms. Over quota: marked failed and left to
        // the abandoned-upload cleanup; it never counts as usage.
        try {
            $this->quota->assertFits($photo->memory->couple, (int) $photo->encrypted_size, $photo->id);
        } catch (StorageQuotaExceeded $exception) {
            $photo->update(['status' => 'failed']);

            throw $exception;
        }

        try {
            if (! $photo->hasDecryptionMetadata()) {
                throw new RuntimeException('Photo is missing encryption metadata.');
            }

            $metadata = $this->photoStorage->verifyObject(
                $photo->storage_key,
                ['file_size' => $photo->encrypted_size],
            );

            // Storage integrity check (SHA-256 of ciphertext). AES-GCM
            // authentication is still verified on the client before display.
            if (! hash_equals($photo->checksum, (string) ($metadata['checksum'] ?? ''))) {
                throw new RuntimeException('Photo checksum mismatch.');
            }

            $photo->forceFill([
                'status' => 'verified',
                'backup_status' => 'pending',
            ])->save();
        } catch (\Throwable $exception) {
            $photo->update([
                'status' => 'failed',
            ]);

            throw new RuntimeException(
                'Photo upload verification failed.',
                previous: $exception,
            );
        }

        // The upload is already safe on primary; a queue outage must not fail it.
        // `photos:backup-pending` re-dispatches anything left pending.
        try {
            BackupMemoryPhoto::dispatch($photo->id);
        } catch (\Throwable $exception) {
            report($exception);
        }

        return $photo->refresh();
    }

    /**
     * Ciphertext stream for download. Falls back to the verified backup when the
     * primary is known bad or unreachable; both hold identical ciphertext and the
     * client authenticates it (GCM) either way.
     *
     * @return resource
     */
    public function readCiphertext(MemoryPhoto $photo)
    {
        $bad = ['mismatch', 'missing'];

        if (! in_array($photo->primary_integrity, $bad, true)) {
            try {
                return $this->photoStorage->readStream($photo->storage_key);
            } catch (\Throwable $exception) {
                report($exception);
            }
        }

        if ($photo->backup_status !== 'verified' || in_array($photo->backup_integrity, $bad, true)) {
            throw new RuntimeException('No readable copy of this photo is available right now.');
        }

        return app('photos.backup')->readStream($photo->storage_key);
    }

    /**
     * Moves the photo to the couple's trash. Neither copy is touched: objects
     * are removed only by the retention purge (PurgeMemoryPhoto).
     */
    public function delete(
        MemoryPhoto $photo,
        ?User $user = null,
    ): void {
        $photo->delete();

        PhotoStorageAudit::record($photo->id, 'trash', 'succeeded', $user ? "user:{$user->id}" : 'system');
    }

    /**
     * Brings a trashed photo back while its retention lasts, then re-verifies
     * the primary copy. A bad or unreachable copy does not block the restore:
     * the backup still holds it and repair/verification jobs take over.
     */
    public function restore(
        MemoryPhoto $photo,
        User $user,
    ): MemoryPhoto {
        // Trashed photos do not count towards the quota, so bringing one back
        // needs free space. The photo simply stays in the trash until then.
        $this->quota->assertFits($photo->memory->couple, (int) ($photo->encrypted_size ?? $photo->file_size));

        // Atomic with the purge's own claim: whichever runs first wins, never both.
        $restored = MemoryPhoto::onlyTrashed()
            ->whereKey($photo->id)
            ->where('status', 'verified')
            ->whereNull('primary_purged_at')
            ->where('deleted_at', '>', now()->subDays(config('photos.trash_retention_days')))
            ->update(['deleted_at' => null, 'updated_at' => now()]);

        if ($restored === 0) {
            throw new RuntimeException('This photo can no longer be restored.');
        }

        PhotoStorageAudit::record($photo->id, 'restore', 'succeeded', "user:{$user->id}");

        $photo->refresh();

        try {
            $integrity = $this->photoStorage
                ->checkIntegrity($photo->storage_key, $photo->checksum, $photo->encrypted_size);
        } catch (\Throwable $exception) {
            // Store unreachable: verify later instead of failing the user's restore.
            report($exception);
            VerifyMemoryPhotoIntegrity::dispatch($photo->id);

            return $photo;
        }

        $photo->forceFill([
            'primary_integrity' => $integrity,
            'integrity_checked_at' => now(),
        ]);

        if ($integrity !== 'ok' && $photo->repair_status !== 'failed') {
            $photo->forceFill(['repair_status' => 'pending']);
        }

        $photo->save();

        if ($photo->repair_status === 'pending') {
            RepairMemoryPhoto::dispatch($photo->id, "user:{$user->id}");
        }

        return $photo;
    }

    /** Trashed photos the couple can still restore, newest deletion first. */
    public function listTrash(Memory $memory)
    {
        return $memory->photos()
            ->onlyTrashed()
            ->where('status', 'verified')
            ->whereNull('primary_purged_at')
            ->where('deleted_at', '>', now()->subDays(config('photos.trash_retention_days')))
            ->orderByDesc('deleted_at')
            ->get();
    }

    private function generateStorageKey(
        Memory $memory,
    ): string {
        return sprintf(
            'couples/%d/memories/%d/photos/%s',
            $memory->couple_id,
            $memory->id,
            (string) str()->uuid(),
        );
    }

    public function upload(
        User $user,
        MemoryPhoto $photo,
        UploadedFile $file,
    ): MemoryPhoto {
        if ($photo->encryption_version === null) {
            throw new RuntimeException(
                'Encryption metadata is required before upload.',
            );
        }

        $photo->update([
            'status' => 'uploading',
        ]);

        try {
            $this->photoStorage->putObject(
                $photo->storage_key,
                $file,
            );

            return $photo->refresh();
        } catch (\Throwable $exception) {
            $photo->update([
                'status' => 'failed',
            ]);

            throw new RuntimeException(
                'Photo upload failed.',
                previous: $exception,
            );
        }
    }

    public function listForMemory(Memory $memory)
    {
        return $memory->photos()
            ->where('status', 'verified')
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get();
    }
}
