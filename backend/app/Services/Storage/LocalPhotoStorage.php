<?php

namespace App\Services\Storage;

use RuntimeException;
use Illuminate\Support\Facades\Storage;

class LocalPhotoStorage implements PhotoStorage
{
    private const DISK = 'local';

    public function createUploadSession(
        string $storageKey,
        array $metadata = [],
    ): array {
        return [
            'storage_key' => $storageKey,
            'upload_url' => null,
            'method' => 'POST',
            'headers' => [],
        ];
    }

    public function finalizeUpload(
        string $storageKey,
    ): array {
        if (! Storage::disk(self::DISK)->exists($storageKey)) {
            throw new RuntimeException(
                'Uploaded photo object was not found.'
            );
        }

        return $this->getObjectMetadata($storageKey);
    }

    public function deleteObject(
        string $storageKey,
    ): void {
        Storage::disk(self::DISK)->delete($storageKey);
    }

    public function verifyObject(
        string $storageKey,
        array $expectedMetadata = [],
    ): array {
        if (! Storage::disk(self::DISK)->exists($storageKey)) {
            throw new RuntimeException(
                'Photo object does not exist.'
            );
        }

        $metadata = $this->getObjectMetadata($storageKey);

        if (
            isset($expectedMetadata['file_size'])
            && $metadata['file_size']
            !== (int) $expectedMetadata['file_size']
        ) {
            throw new RuntimeException(
                'Uploaded photo size does not match expected size.'
            );
        }

        return $metadata;
    }

    public function getObjectMetadata(
        string $storageKey,
    ): array {
        $disk = Storage::disk(self::DISK);

        if (! $disk->exists($storageKey)) {
            throw new RuntimeException(
                'Photo object does not exist.'
            );
        }

        return [
            'file_size' => $disk->size($storageKey),
            'mime_type' => (new \finfo(FILEINFO_MIME_TYPE))->file(
                $disk->path($storageKey),
            ),
            'checksum' => md5_file(
                $disk->path($storageKey),
            ),
        ];
    }

    public function getObject(
        string $storageKey,
    ): mixed {
        $disk = Storage::disk(self::DISK);

        if (! $disk->exists($storageKey)) {
            throw new RuntimeException(
                'Photo object does not exist.'
            );
        }

        return $disk->path($storageKey);
    }
}
