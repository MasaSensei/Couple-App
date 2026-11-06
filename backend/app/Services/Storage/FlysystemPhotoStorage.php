<?php

namespace App\Services\Storage;

use Illuminate\Contracts\Filesystem\Filesystem;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use RuntimeException;

/**
 * Stores opaque ciphertext on any Laravel disk (S3-compatible in practice).
 * One instance per copy: primary and backup differ only by disk name.
 */
class FlysystemPhotoStorage implements PhotoStorage
{
    public function __construct(
        private readonly string $diskName,
    ) {}

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
        return $this->getObjectMetadata($storageKey);
    }

    public function deleteObject(
        string $storageKey,
    ): void {
        $this->disk()->delete($storageKey);
    }

    public function verifyObject(
        string $storageKey,
        array $expectedMetadata = [],
    ): array {
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

    public function checkIntegrity(
        string $storageKey,
        string $expectedChecksum,
        ?int $expectedSize = null,
    ): string {
        try {
            $metadata = $this->getObjectMetadata($storageKey);
        } catch (PhotoObjectMissingException) {
            return 'missing';
        }

        $matches = hash_equals($expectedChecksum, $metadata['checksum'])
            && ($expectedSize === null || $metadata['file_size'] === $expectedSize);

        return $matches ? 'ok' : 'mismatch';
    }

    public function getObjectMetadata(
        string $storageKey,
    ): array {
        $this->ensureExists($storageKey);

        // Hash the bytes ourselves: provider ETags are not SHA-256 and are not trusted.
        $stream = $this->readStream($storageKey);

        try {
            $context = hash_init('sha256');
            $size = hash_update_stream($context, $stream);
        } finally {
            fclose($stream);
        }

        return [
            'file_size' => $size,
            'checksum' => hash_final($context),
        ];
    }

    public function readStream(
        string $storageKey,
    ) {
        $this->ensureExists($storageKey);

        $stream = $this->disk()->readStream($storageKey);

        if (! is_resource($stream)) {
            throw new RuntimeException('Unable to read photo object.');
        }

        return $stream;
    }

    public function putObject(
        string $storageKey,
        mixed $file,
    ): array {
        if ($file instanceof UploadedFile) {
            $stream = fopen($file->getRealPath(), 'rb');
        } elseif (is_resource($file)) {
            $stream = $file;
        } else {
            throw new RuntimeException('Invalid uploaded photo.');
        }

        if ($stream === false) {
            throw new RuntimeException('Unable to read uploaded photo.');
        }

        try {
            if (! $this->disk()->put($storageKey, $stream)) {
                throw new RuntimeException('Failed to store uploaded photo.');
            }
        } finally {
            fclose($stream);
        }

        return $this->getObjectMetadata($storageKey);
    }

    private function ensureExists(string $storageKey): void
    {
        if (! $this->disk()->exists($storageKey)) {
            throw new PhotoObjectMissingException('Photo object does not exist.');
        }
    }

    private function disk(): Filesystem
    {
        return Storage::disk($this->diskName);
    }
}
