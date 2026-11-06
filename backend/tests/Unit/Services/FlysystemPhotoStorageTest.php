<?php

namespace Tests\Unit\Services;

use App\Services\Storage\FlysystemPhotoStorage;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Tests\TestCase;

class FlysystemPhotoStorageTest extends TestCase
{
    public function test_primary_and_backup_instances_write_to_their_own_disks(): void
    {
        Storage::fake('photos_primary');
        Storage::fake('photos_backup');

        $primary = new FlysystemPhotoStorage('photos_primary');
        $backup = new FlysystemPhotoStorage('photos_backup');
        $ciphertext = random_bytes(4096);

        $stream = fopen('php://temp', 'w+b');
        fwrite($stream, $ciphertext);
        rewind($stream);

        $metadata = $primary->putObject('couples/1/photo', $stream);

        $this->assertSame(hash('sha256', $ciphertext), $metadata['checksum']);
        $this->assertSame(strlen($ciphertext), $metadata['file_size']);
        $this->assertFalse(Storage::disk('photos_backup')->exists('couples/1/photo'));

        // Byte-for-byte copy primary -> backup, the shape the backup job will use.
        $backup->putObject('couples/1/photo', $primary->readStream('couples/1/photo'));

        $this->assertSame($ciphertext, Storage::disk('photos_backup')->get('couples/1/photo'));
        $this->assertSame($metadata, $backup->getObjectMetadata('couples/1/photo'));
    }

    public function test_missing_object_throws(): void
    {
        Storage::fake('photos_primary');

        $this->expectException(RuntimeException::class);

        (new FlysystemPhotoStorage('photos_primary'))->readStream('missing');
    }
}
