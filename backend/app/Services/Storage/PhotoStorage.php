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

    public function getObjectMetadata(
        string $storageKey,
    ): array;

    public function getObject(
        string $storageKey,
    ): mixed;

    public function deleteObject(
        string $storageKey,
    ): void;
}
