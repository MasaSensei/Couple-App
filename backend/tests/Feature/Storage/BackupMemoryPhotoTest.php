<?php

namespace Tests\Feature\Storage;

use App\Jobs\BackupMemoryPhoto;
use App\Models\Couple;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\User;
use App\Services\Memory\MemoryPhotoService;
use App\Services\Storage\FlysystemPhotoStorage;
use App\Services\Storage\PhotoStorage;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Mockery;
use RuntimeException;
use Tests\TestCase;

class BackupMemoryPhotoTest extends TestCase
{
    use RefreshDatabase;

    private string $ciphertext;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('photos_primary');
        Storage::fake('photos_backup');

        $this->ciphertext = random_bytes(2048);
    }

    private function photo(array $attributes = []): MemoryPhoto
    {
        $user = User::factory()->create();
        $memory = Memory::factory()->create([
            'couple_id' => Couple::factory()->create()->id,
            'created_by' => $user->id,
        ]);

        $photo = MemoryPhoto::create([
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
        ]);
        $photo->forceFill(['backup_status' => 'pending', ...$attributes])->save();

        Storage::disk('photos_primary')->put($photo->storage_key, $this->ciphertext);

        return $photo->refresh();
    }

    private function backupMock(): FlysystemPhotoStorage
    {
        $mock = Mockery::mock(FlysystemPhotoStorage::class, ['photos_backup'])->makePartial();
        $this->app->instance('photos.backup', $mock);

        return $mock;
    }

    public function test_completing_an_upload_queues_backup_and_is_not_yet_protected(): void
    {
        Queue::fake();
        $photo = $this->photo(['backup_status' => null]);
        $photo->forceFill(['status' => 'uploading'])->save();

        $photo = app(MemoryPhotoService::class)->complete($photo);

        $this->assertSame('pending', $photo->backup_status);
        $this->assertSame('backup_pending', $photo->protectionStatus());
        Queue::assertPushed(BackupMemoryPhoto::class, fn ($job) => $job->photoId === $photo->id);
    }

    public function test_backup_copies_ciphertext_verifies_it_and_marks_protected(): void
    {
        $photo = $this->photo();

        BackupMemoryPhoto::dispatchSync($photo->id);

        $photo->refresh();
        $this->assertSame($this->ciphertext, Storage::disk('photos_backup')->get($photo->storage_key));
        $this->assertSame('verified', $photo->backup_status);
        $this->assertNotNull($photo->backup_verified_at);
        $this->assertSame('protected', $photo->protectionStatus());
    }

    public function test_rerun_after_crash_recognises_existing_copy_without_rewriting(): void
    {
        // Worker died after the copy, before the DB update.
        $photo = $this->photo();
        Storage::disk('photos_backup')->put($photo->storage_key, $this->ciphertext);
        $this->backupMock()->shouldNotReceive('putObject');

        BackupMemoryPhoto::dispatchSync($photo->id);
        BackupMemoryPhoto::dispatchSync($photo->id);

        $this->assertSame('protected', $photo->refresh()->protectionStatus());
    }

    public function test_backup_store_unavailable_keeps_primary_and_never_claims_protected(): void
    {
        $photo = $this->photo();
        $backup = $this->backupMock();
        $backup->shouldReceive('getObjectMetadata')->andThrow(new RuntimeException('Connection refused.'));
        $backup->shouldReceive('putObject')->andThrow(new RuntimeException('Connection refused.'));

        $job = new BackupMemoryPhoto($photo->id);

        try {
            $job->handle();
            $this->fail('Expected the attempt to throw so the queue retries it.');
        } catch (RuntimeException) {
        }

        $photo->refresh();
        $this->assertSame('pending', $photo->backup_status, 'Still retryable after one attempt.');
        $this->assertStringContainsString('Connection refused', $photo->backup_error);

        // Retries exhausted.
        $job->failed(new RuntimeException('Connection refused.'));

        $photo->refresh();
        $this->assertSame('failed', $photo->backup_status);
        $this->assertSame('degraded', $photo->protectionStatus());
        $this->assertSame($this->ciphertext, Storage::disk('photos_primary')->get($photo->storage_key));
    }

    public function test_corrupt_primary_is_never_copied_to_backup(): void
    {
        $photo = $this->photo();
        Storage::disk('photos_primary')->put($photo->storage_key, 'tampered');

        (new BackupMemoryPhoto($photo->id))->handle();

        $photo->refresh();
        $this->assertFalse(Storage::disk('photos_backup')->exists($photo->storage_key));
        $this->assertSame('failed', $photo->backup_status);
        $this->assertNotSame('protected', $photo->protectionStatus());
    }

    public function test_backup_checksum_mismatch_after_copy_is_not_marked_verified(): void
    {
        $photo = $this->photo();
        $this->backupMock()->shouldReceive('getObjectMetadata')
            ->andReturn(['file_size' => strlen($this->ciphertext), 'checksum' => str_repeat('0', 64)]);

        $this->expectExceptionMessage('Backup checksum mismatch after copy.');

        try {
            (new BackupMemoryPhoto($photo->id))->handle();
        } finally {
            $this->assertSame('pending', $photo->refresh()->backup_status);
        }
    }

    public function test_unverified_upload_is_not_backed_up(): void
    {
        $photo = $this->photo(['backup_status' => null]);
        $photo->forceFill(['status' => 'uploading'])->save();

        BackupMemoryPhoto::dispatchSync($photo->id);

        $this->assertFalse(Storage::disk('photos_backup')->exists($photo->storage_key));
        $this->assertNull($photo->refresh()->backup_status);
    }

    public function test_only_one_backup_job_is_queued_per_photo(): void
    {
        Queue::fake();
        $photo = $this->photo();

        BackupMemoryPhoto::dispatch($photo->id);
        BackupMemoryPhoto::dispatch($photo->id);

        Queue::assertPushed(BackupMemoryPhoto::class, 1);
    }

    public function test_sweeper_redispatches_only_stale_pending_backups(): void
    {
        Queue::fake();
        $stale = $this->photo();
        $fresh = $this->photo();
        $failed = $this->photo(['backup_status' => 'failed']);
        MemoryPhoto::whereKey([$stale->id, $failed->id])->update(['updated_at' => now()->subHour()]);

        $this->artisan('photos:backup-pending')->assertSuccessful();

        Queue::assertPushed(BackupMemoryPhoto::class, fn ($job) => $job->photoId === $stale->id);
        Queue::assertNotPushed(BackupMemoryPhoto::class, fn ($job) => in_array($job->photoId, [$fresh->id, $failed->id], true));
    }

    public function test_backup_storage_is_a_separate_instance_from_primary(): void
    {
        $this->assertNotSame(app(PhotoStorage::class), app('photos.backup'));
    }
}
