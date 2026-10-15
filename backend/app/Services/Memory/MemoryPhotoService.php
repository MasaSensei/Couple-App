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

                    'original_filename' =>
                    $data['original_filename'] ?? null,

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
            $expectedMetadata = [];

            if ($photo->encryption_version !== null) {
                $expectedMetadata = [
                    'encrypted_size' => $photo->encrypted_size,
                    'checksum' => $photo->checksum,
                ];
            } else {
                $expectedMetadata = [
                    'file_size' => $photo->file_size,
                ];
            }

            $metadata = $this->photoStorage->verifyObject(
                $photo->storage_key,
                $expectedMetadata,
            );

            $photo->update([
                'status' => 'verified',
                'checksum' => $metadata['checksum'] ?? null,
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
