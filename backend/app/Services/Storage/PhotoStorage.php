<?php

namespace App\Services\Storage;

interface PhotoStorage
{
    public function createUploadSession(
        string $storageKey,
        array $metadata = [],
    ): array;

    public function finalizeUpload(
        string $storageKey,
    ): array;

    public function verifyObject(
        string $storageKey,
        array $expectedMetadata = [],
    ): array;

    /**
     * Re-hash the stored bytes against a trusted reference (the DB checksum,
     * never anything read from the store itself).
     *
     * @return 'ok'|'mismatch'|'missing'
     * @throws \Throwable when the store cannot be reached; never reported as data loss.
     */
    public function checkIntegrity(
        string $storageKey,
        string $expectedChecksum,
        ?int $expectedSize = null,
    ): string;

    public function getObjectMetadata(
        string $storageKey,
    ): array;

    /**
     * @return resource Readable ciphertext stream; the caller closes it.
     */
    public function readStream(
        string $storageKey,
    );

    /**
     * Every stored key under $prefix (current versions only). Used by reconciliation.
     *
     * @return list<string>
     */
    public function listKeys(
        string $prefix = '',
    ): array;

    public function deleteObject(
        string $storageKey,
    ): void;

    /**
     * @param \Illuminate\Http\UploadedFile|resource $file Consumed and closed.
     */
    public function putObject(
        string $storageKey,
        mixed $file,
    ): array;
}
