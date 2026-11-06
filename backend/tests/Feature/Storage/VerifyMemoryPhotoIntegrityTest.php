<?php

namespace Tests\Feature\Storage;

use App\Jobs\BackupMemoryPhoto;
use App\Jobs\RepairMemoryPhoto;
use App\Jobs\VerifyMemoryPhotoIntegrity;
use App\Models\Couple;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\User;
use App\Services\Storage\FlysystemPhotoStorage;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use LogicException;
use Mockery;
use RuntimeException;
use Tests\TestCase;

class VerifyMemoryPhotoIntegrityTest extends TestCase
{
    use RefreshDatabase;

    private string $ciphertext;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('photos_primary');
        Storage::fake('photos_backup');
        // Detection is tested in isolation; RepairMemoryPhotoTest covers what follows.
        Queue::fake([RepairMemoryPhoto::class]);

        $this->ciphertext = random_bytes(2048);
    }

    /** A protected photo: both copies written and verified. */
    private function photo(array $attributes = []): MemoryPhoto
    {
        $user = User::factory()->create();
        $memory = Memory::factory()->create([
            'couple_id' => Couple::factory()->create()->id,
            'created_by' => $user->id,
        ]);

        $photo = (new MemoryPhoto)->forceFill([
            'memory_id' => $memory->id,
            'uploaded_by' => $user->id,
            'storage_key' => 'couples/1/memories/1/photos/'.fake()->uuid(),
            'mime_type' => 'image/jpeg',
            'file_size' => 100,
            'encryption_version' => 1,
            'encryption_algorithm' => 'AES-256-GCM',
            'key_id' => 'key-1',
            'nonce' => base64_encode(random_bytes(12)),
            'mac' => base64_encode(random_bytes(16)),
            'checksum' => hash('sha256', $this->ciphertext),
            'encrypted_size' => strlen($this->ciphertext),
            'status' => 'verified',
            'backup_status' => 'verified',
            ...$attributes,
        ]);
        $photo->save();

        Storage::disk('photos_primary')->put($photo->storage_key, $this->ciphertext);
        Storage::disk('photos_backup')->put($photo->storage_key, $this->ciphertext);

        return $photo->refresh();
    }

    public function test_healthy_copies_are_recorded_ok_and_stay_protected(): void
    {
        $photo = $this->photo();

        VerifyMemoryPhotoIntegrity::dispatchSync($photo->id);

        $photo->refresh();
        $this->assertSame('ok', $photo->primary_integrity);
        $this->assertSame('ok', $photo->backup_integrity);
        $this->assertNotNull($photo->integrity_checked_at);
        $this->assertSame('protected', $photo->protectionStatus());
    }

    public function test_corrupt_primary_is_detected_and_no_object_is_touched(): void
    {
        $photo = $this->photo();
        Storage::disk('photos_primary')->put($photo->storage_key, 'bit-rot');

        VerifyMemoryPhotoIntegrity::dispatchSync($photo->id);

        $photo->refresh();
        $this->assertSame('mismatch', $photo->primary_integrity);
        $this->assertSame('ok', $photo->backup_integrity);
        $this->assertSame('restoring', $photo->protectionStatus());
        // Detection only: the suspect copy is left for repair, the good one untouched.
        $this->assertSame('bit-rot', Storage::disk('photos_primary')->get($photo->storage_key));
        $this->assertSame($this->ciphertext, Storage::disk('photos_backup')->get($photo->storage_key));
    }

    public function test_missing_backup_object_is_detected(): void
    {
        $photo = $this->photo();
        Storage::disk('photos_backup')->delete($photo->storage_key);

        VerifyMemoryPhotoIntegrity::dispatchSync($photo->id);

        $photo->refresh();
        $this->assertSame('ok', $photo->primary_integrity);
        $this->assertSame('missing', $photo->backup_integrity);
        $this->assertSame('restoring', $photo->protectionStatus());
    }

    public function test_unreachable_store_is_never_recorded_as_data_loss(): void
    {
        $photo = $this->photo(['primary_integrity' => 'ok', 'backup_integrity' => 'ok']);
        $backup = Mockery::mock(FlysystemPhotoStorage::class, ['photos_backup'])->makePartial();
        $backup->shouldReceive('getObjectMetadata')->andThrow(new RuntimeException('Connection refused.'));
        $this->app->instance('photos.backup', $backup);

        try {
            (new VerifyMemoryPhotoIntegrity($photo->id))->handle();
            $this->fail('Expected the check to throw so it is retried.');
        } catch (RuntimeException) {
        }

        $photo->refresh();
        $this->assertSame('ok', $photo->backup_integrity);
        $this->assertNull($photo->integrity_checked_at);
        $this->assertSame('protected', $photo->protectionStatus());
    }

    public function test_backup_still_being_written_is_not_checked(): void
    {
        $photo = $this->photo(['backup_status' => 'pending']);
        Storage::disk('photos_backup')->delete($photo->storage_key);

        VerifyMemoryPhotoIntegrity::dispatchSync($photo->id);

        $photo->refresh();
        $this->assertSame('ok', $photo->primary_integrity);
        $this->assertNull($photo->backup_integrity);
    }

    public function test_trashed_photos_are_still_checked(): void
    {
        $photo = $this->photo();
        $photo->delete();
        Storage::disk('photos_primary')->put($photo->storage_key, 'bit-rot');

        VerifyMemoryPhotoIntegrity::dispatchSync($photo->id);

        $this->assertSame('mismatch', MemoryPhoto::withTrashed()->find($photo->id)->primary_integrity);
    }

    public function test_scheduler_queues_never_checked_first_then_stale_and_skips_fresh(): void
    {
        Queue::fake();
        $fresh = $this->photo(['integrity_checked_at' => now()->subDay()]);
        $stale = $this->photo(['integrity_checked_at' => now()->subDays(10)]);
        $never = $this->photo();
        $uploading = $this->photo(['status' => 'uploading']);

        $this->artisan('photos:verify-integrity', ['--limit' => 1])->assertSuccessful();
        Queue::assertPushed(VerifyMemoryPhotoIntegrity::class, 1);
        Queue::assertPushed(VerifyMemoryPhotoIntegrity::class, fn ($job) => $job->photoId === $never->id);

        $this->artisan('photos:verify-integrity')->assertSuccessful();
        Queue::assertPushed(VerifyMemoryPhotoIntegrity::class, fn ($job) => $job->photoId === $stale->id);
        Queue::assertNotPushed(VerifyMemoryPhotoIntegrity::class, fn ($job) => in_array($job->photoId, [$fresh->id, $uploading->id], true));
    }

    public function test_checksum_of_a_verified_photo_is_immutable(): void
    {
        $photo = $this->photo();

        $this->expectException(LogicException::class);

        $photo->update(['checksum' => hash('sha256', 'corrupt bytes')]);
    }

    public function test_backup_job_reports_missing_primary_as_missing(): void
    {
        $photo = $this->photo(['backup_status' => 'pending']);
        Storage::disk('photos_backup')->delete($photo->storage_key);
        Storage::disk('photos_primary')->delete($photo->storage_key);

        (new BackupMemoryPhoto($photo->id))->handle();

        $photo->refresh();
        $this->assertSame('missing', $photo->primary_integrity);
        $this->assertSame('failed', $photo->backup_status);
        $this->assertStringContainsString('Primary missing', $photo->backup_error);
    }
}
