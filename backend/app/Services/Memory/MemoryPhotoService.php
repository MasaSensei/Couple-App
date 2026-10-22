<?php

namespace App\Services\Memory;

use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\User;
use App\Services\Storage\PhotoStorage;
use Illuminate\Support\Facades\DB;
use Illuminate\Http\UploadedFile;
use RuntimeException;

class MemoryPhotoService
{

    public function __construct(
        private readonly PhotoStorage $photoStorage,
    ) {}

    public function createUploadSession(
        User $user,
        Memory $memory,
        array $data,
    ): array {
        $storageKey = $this->generateStorageKey(
            $memory,
        );

        $photo = DB::transaction(
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

        $photo->update([
            'encryption_version' => $data['encryption_version'],
            'encryption_algorithm' => $data['encryption_algorithm'],
            'key_id' => $data['key_id'],
            'nonce' => $data['nonce'],
            'encrypted_size' => $data['encrypted_size'],
            'checksum' => strtolower($data['checksum']),
            'mac' => $data['mac'],
        ]);

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

        $photo->update([
            'status' => 'uploading',
        ]);

        try {
            if ($photo->encryption_version === null || $photo->checksum === null) {
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

            $photo->update([
                'status' => 'verified',
            ]);

            return $photo->refresh();
        } catch (\Throwable $exception) {
            $photo->update([
                'status' => 'failed',
            ]);

            throw new RuntimeException(
                'Photo upload verification failed.',
                previous: $exception,
            );
        }
    }

    public function delete(
        MemoryPhoto $photo,
    ): void {
        $this->photoStorage->deleteObject(
            $photo->storage_key,
        );

        $photo->delete();
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
