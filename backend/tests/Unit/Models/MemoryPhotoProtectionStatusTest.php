<?php

namespace Tests\Unit\Models;

use App\Models\MemoryPhoto;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class MemoryPhotoProtectionStatusTest extends TestCase
{
    private const COMPLETE = [
        'checksum' => 'abc', 'encryption_version' => 1, 'key_id' => 'k', 'nonce' => 'n', 'mac' => 'm',
    ];

    public static function cases(): array
    {
        return [
            'upload in progress' => [['status' => 'uploading'], 'pending_upload'],
            'upload failed' => [['status' => 'failed'], 'failed'],
            'primary only' => [['status' => 'verified', 'backup_status' => 'pending'], 'backup_pending'],
            'backup failed' => [['status' => 'verified', 'backup_status' => 'failed'], 'degraded'],
            'both copies verified' => [['status' => 'verified', 'backup_status' => 'verified'], 'protected'],
            'backup verified, upload not' => [['status' => 'uploading', 'backup_status' => 'verified'], 'pending_upload'],
            'both verified, mac missing' => [['status' => 'verified', 'backup_status' => 'verified', 'mac' => null], 'degraded'],
            'both verified, nonce missing' => [['status' => 'verified', 'backup_status' => 'verified', 'nonce' => ''], 'degraded'],
            'both verified, but trashed' => [['status' => 'verified', 'backup_status' => 'verified', 'deleted_at' => '2026-10-24 00:00:00'], 'deleted'],
        ];
    }

    #[DataProvider('cases')]
    public function test_protection_status(array $attributes, string $expected): void
    {
        $photo = (new MemoryPhoto)->forceFill([...self::COMPLETE, ...$attributes]);

        $this->assertSame($expected, $photo->protectionStatus());
    }
}
