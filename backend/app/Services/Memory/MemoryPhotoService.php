<?php

namespace App\Services\Memory;

use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\User;
use App\Services\Storage\PhotoStorage;
use Illuminate\Support\Facades\DB;
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

                    'file_size' =>
                    $data['file_size'],

                    'width' =>
                    $data['width'] ?? null,

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

    public function complete(
        MemoryPhoto $photo,
    ): MemoryPhoto {
        $photo->update([
            'status' => 'uploading',
        ]);

        try {
            $metadata = $this->photoStorage
                ->verifyObject(
                    $photo->storage_key,
                    [
                        'file_size' => $photo->file_size,
                    ],
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
}
