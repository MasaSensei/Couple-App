<?php

namespace App\Services;

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
    ): MemoryPhoto {
        $storageKey = sprintf(
            'couples/%d/memories/%d/photos/%s',
            $memory->couple_id,
            $memory->id,
            (string) str()->uuid(),
        );

        return DB::transaction(
            function () use (
                $user,
                $memory,
                $data,
                $storageKey,
            ): MemoryPhoto {
                $photo = MemoryPhoto::create([
                    'memory_id' => $memory->id,
                    'uploaded_by' => $user->id,
                    'storage_key' => $storageKey,
                    'original_filename' =>
                    $data['original_filename'] ?? null,
                    'mime_type' => $data['mime_type'],
                    'file_size' => $data['file_size'],
                    'width' => $data['width'] ?? null,
                    'height' => $data['height'] ?? null,
                    'status' => 'pending',
                    'sort_order' =>
                    $data['sort_order'] ?? 0,
                ]);

                return $photo;
            },
        );
    }
}
