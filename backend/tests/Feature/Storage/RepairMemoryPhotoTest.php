<?php

namespace Tests\Feature\Storage;

use App\Jobs\RepairMemoryPhoto;
use App\Jobs\VerifyMemoryPhotoIntegrity;
use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\PhotoStorageAudit;
use App\Models\User;
use App\Services\Storage\FlysystemPhotoStorage;
use App\Services\Storage\PhotoStorage;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Mockery;
use RuntimeException;
use Tests\TestCase;

class RepairMemoryPhotoTest extends TestCase
{
    use RefreshDatabase;

    private string $ciphertext;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('photos_primary');
        Storage::fake('photos_backup');

        $this->ciphertext = random_bytes(2048);
    }

    private function photo(array $attributes = []): MemoryPhoto
    {
        $this->user = User::factory()->create();
        $couple = Couple::factory()->create();
        CoupleMember::create(['couple_id' => $couple->id, 'user_id' => $this->user->id]);
        $memory = Memory::factory()->create(['couple_id' => $couple->id, 'created_by' => $this->user->id]);

        $photo = (new MemoryPhoto)->forceFill([
            'memory_id' => $memory->id,
            'uploaded_by' => $this->user->id,
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

    private function primary(MemoryPhoto $photo): ?string
    {
        return Storage::disk('photos_primary')->get($photo->storage_key);
    }

    private function backup(MemoryPhoto $photo): ?string
    {
        return Storage::disk('photos_backup')->get($photo->storage_key);
    }

    public function test_corrupt_primary_is_restored_from_verified_backup_and_reverified(): void
    {
        $photo = $this->photo(['primary_integrity' => 'mismatch', 'repair_status' => 'pending']);
        Storage::disk('photos_primary')->put($photo->storage_key, 'bit-rot');
        $this->assertSame('restoring', $photo->protectionStatus());

        RepairMemoryPhoto::dispatchSync($photo->id);

        $photo->refresh();
        $this->assertSame($this->ciphertext, $this->primary($photo), 'Ciphertext restored byte-for-byte.');
        $this->assertSame('ok', $photo->primary_integrity);
        $this->assertNull($photo->repair_status);
        $this->assertSame('protected', $photo->protectionStatus());
        $this->assertDatabaseHas('photo_storage_audits', [
            'memory_photo_id' => $photo->id, 'action' => 'repair', 'result' => 'succeeded', 'actor' => 'system',
        ]);
    }

    public function test_missing_primary_is_restored(): void
    {
        $photo = $this->photo();
        Storage::disk('photos_primary')->delete($photo->storage_key);

        RepairMemoryPhoto::dispatchSync($photo->id, 'user:7');

        $this->assertSame($this->ciphertext, $this->primary($photo));
        $this->assertSame('user:7', PhotoStorageAudit::latest('id')->first()->actor);
    }

    public function test_corrupt_backup_is_recopied_from_primary_without_touching_primary(): void
    {
        $photo = $this->photo(['backup_integrity' => 'mismatch']);
        Storage::disk('photos_backup')->put($photo->storage_key, 'bit-rot');

        RepairMemoryPhoto::dispatchSync($photo->id);

        $photo->refresh();
        $this->assertSame($this->ciphertext, $this->backup($photo));
        $this->assertSame($this->ciphertext, $this->primary($photo));
        $this->assertSame('ok', $photo->backup_integrity);
        $this->assertSame('protected', $photo->protectionStatus());
    }

    public function test_both_copies_bad_writes_nothing_keeps_metadata_and_needs_an_operator(): void
    {
        $photo = $this->photo();
        Storage::disk('photos_primary')->put($photo->storage_key, 'bad-primary');
        Storage::disk('photos_backup')->put($photo->storage_key, 'bad-backup');
        $metadata = $photo->only(MemoryPhoto::DECRYPTION_METADATA);

        RepairMemoryPhoto::dispatchSync($photo->id);

        $photo->refresh();
        // A corrupt backup never replaces the primary (and vice versa).
        $this->assertSame('bad-primary', $this->primary($photo));
        $this->assertSame('bad-backup', $this->backup($photo));
        $this->assertSame('failed', $photo->repair_status);
        $this->assertSame('degraded', $photo->protectionStatus());
        $this->assertSame($metadata, $photo->only(MemoryPhoto::DECRYPTION_METADATA));
        $this->assertDatabaseHas('photo_storage_audits', ['memory_photo_id' => $photo->id, 'result' => 'failed']);
        $this->assertDatabaseMissing('photo_storage_audits', ['memory_photo_id' => $photo->id, 'result' => 'succeeded']);
    }

    public function test_restored_copy_that_fails_verification_is_not_marked_healthy(): void
    {
        $photo = $this->photo(['primary_integrity' => 'mismatch', 'repair_status' => 'pending']);
        Storage::disk('photos_primary')->put($photo->storage_key, 'bit-rot');

        // The write "succeeds" but the store keeps returning the wrong bytes.
        $primary = Mockery::mock(FlysystemPhotoStorage::class, ['photos_primary'])->makePartial();
        $primary->shouldReceive('putObject')->andReturnUsing(function ($key, $stream) {
            fclose($stream);

            return [];
        });
        $this->app->instance(PhotoStorage::class, $primary);

        try {
            (new RepairMemoryPhoto($photo->id))->handle();
            $this->fail('Expected unverified restore to throw.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('failed verification', $exception->getMessage());
        }

        $photo->refresh();
        $this->assertSame('restoring', $photo->protectionStatus());
        $this->assertSame($this->ciphertext, $this->backup($photo), 'Source copy untouched.');
        $this->assertDatabaseMissing('photo_storage_audits', ['result' => 'succeeded']);
    }

    public function test_primary_that_recovered_before_repair_is_not_rewritten(): void
    {
        $photo = $this->photo(['primary_integrity' => 'mismatch', 'repair_status' => 'pending']);
        $primary = Mockery::mock(FlysystemPhotoStorage::class, ['photos_primary'])->makePartial();
        $primary->shouldNotReceive('putObject');
        $this->app->instance(PhotoStorage::class, $primary);

        RepairMemoryPhoto::dispatchSync($photo->id);

        $photo->refresh();
        $this->assertSame('ok', $photo->primary_integrity);
        $this->assertNull($photo->repair_status);
        $this->assertDatabaseHas('photo_storage_audits', ['memory_photo_id' => $photo->id, 'result' => 'skipped']);
    }

    public function test_unreachable_store_changes_nothing_and_is_retried(): void
    {
        $photo = $this->photo(['primary_integrity' => 'mismatch', 'repair_status' => 'pending']);
        $backup = Mockery::mock(FlysystemPhotoStorage::class, ['photos_backup'])->makePartial();
        $backup->shouldReceive('getObjectMetadata')->andThrow(new RuntimeException('Connection refused.'));
        $this->app->instance('photos.backup', $backup);

        $this->expectException(RuntimeException::class);

        try {
            (new RepairMemoryPhoto($photo->id))->handle();
        } finally {
            $this->assertSame('pending', $photo->refresh()->repair_status);
            $this->assertSame(0, PhotoStorageAudit::count());
        }
    }

    public function test_integrity_check_that_finds_a_bad_copy_queues_a_repair(): void
    {
        Queue::fake([RepairMemoryPhoto::class]);
        $photo = $this->photo();
        Storage::disk('photos_primary')->put($photo->storage_key, 'bit-rot');

        VerifyMemoryPhotoIntegrity::dispatchSync($photo->id);

        $this->assertSame('restoring', $photo->refresh()->protectionStatus());
        Queue::assertPushed(RepairMemoryPhoto::class, fn ($job) => $job->photoId === $photo->id);
    }

    public function test_download_falls_back_to_verified_backup_when_primary_is_bad(): void
    {
        $photo = $this->photo(['primary_integrity' => 'mismatch']);
        Storage::disk('photos_primary')->put($photo->storage_key, 'bit-rot');

        $response = $this->actingAs($this->user)
            ->get("/api/v1/memory-photos/{$photo->id}/content")
            ->assertOk()
            ->assertHeader('Content-Type', 'application/octet-stream');

        $this->assertSame($this->ciphertext, $response->streamedContent());
    }

    public function test_download_falls_back_when_primary_object_is_gone_unnoticed(): void
    {
        $photo = $this->photo();
        Storage::disk('photos_primary')->delete($photo->storage_key);

        $response = $this->actingAs($this->user)
            ->get("/api/v1/memory-photos/{$photo->id}/content")
            ->assertOk();

        $this->assertSame($this->ciphertext, $response->streamedContent());
    }

    public function test_download_with_no_readable_copy_is_a_clear_503(): void
    {
        $photo = $this->photo(['primary_integrity' => 'mismatch', 'backup_status' => 'pending']);

        $this->actingAs($this->user)
            ->get("/api/v1/memory-photos/{$photo->id}/content")
            ->assertStatus(503)
            ->assertJsonPath('success', false);
    }
}
