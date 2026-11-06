<?php

namespace Tests\Feature\Storage;

use App\Jobs\BackupMemoryPhoto;
use App\Jobs\PurgeMemoryPhoto;
use App\Jobs\RepairMemoryPhoto;
use App\Jobs\VerifyMemoryPhotoIntegrity;
use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\PhotoStorageAudit;
use App\Models\User;
use App\Services\Storage\FlysystemPhotoStorage;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Mockery;
use RuntimeException;
use Tests\TestCase;

/**
 * STEP 14: one test per failure scenario (docs/storage/reliability.md §4 and §17).
 * F (database restore) lives in DatabaseRestoreDrillTest because it needs real pg_dump.
 */
class FailureInjectionTest extends TestCase
{
    use RefreshDatabase;

    private string $ciphertext;

    private User $user;

    private Memory $memory;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('photos_primary');
        Storage::fake('photos_backup');

        $this->ciphertext = random_bytes(4096);
        $this->user = User::factory()->create();
        $couple = Couple::factory()->create();
        CoupleMember::create(['couple_id' => $couple->id, 'user_id' => $this->user->id]);
        $this->memory = Memory::factory()->create(['couple_id' => $couple->id, 'created_by' => $this->user->id]);
    }

    private function photo(array $attributes = [], bool $primary = true, bool $backup = true): MemoryPhoto
    {
        $photo = (new MemoryPhoto)->forceFill([
            'memory_id' => $this->memory->id,
            'uploaded_by' => $this->user->id,
            'storage_key' => 'couples/1/memories/1/photos/'.fake()->uuid(),
            'mime_type' => 'image/jpeg',
            'file_size' => 100,
            'encryption_version' => '1', 'encryption_algorithm' => 'AES-256-GCM', 'key_id' => 'key-1',
            'nonce' => base64_encode(random_bytes(12)), 'mac' => base64_encode(random_bytes(16)),
            'checksum' => hash('sha256', $this->ciphertext),
            'encrypted_size' => strlen($this->ciphertext),
            'status' => 'verified',
            'backup_status' => 'verified',
            ...$attributes,
        ]);
        $photo->save();

        $primary && Storage::disk('photos_primary')->put($photo->storage_key, $this->ciphertext);
        $backup && Storage::disk('photos_backup')->put($photo->storage_key, $this->ciphertext);

        return $photo->refresh();
    }

    private function brokenStore(string $disk, array $methods): FlysystemPhotoStorage
    {
        $store = Mockery::mock(FlysystemPhotoStorage::class, [$disk])->makePartial();

        foreach ($methods as $method) {
            $store->shouldReceive($method)->andThrow(new RuntimeException('Connection refused.'));
        }

        return $store;
    }

    public function test_a_primary_upload_failure_is_never_reported_as_saved(): void
    {
        $this->app->instance(\App\Services\Storage\PhotoStorage::class, $this->brokenStore('photos_primary', ['putObject']));
        $photo = $this->photo(['status' => 'pending', 'backup_status' => null], primary: false, backup: false);

        $this->actingAs($this->user)
            ->post("/api/v1/memory-photos/{$photo->id}/upload", ['photo' => UploadedFile::fake()->create('c.bin', 4)])
            ->assertStatus(422)
            ->assertJsonPath('success', false);

        $photo->refresh();
        $this->assertSame('failed', $photo->status);
        $this->assertSame('failed', $photo->protectionStatus());
        $this->actingAs($this->user)->getJson('/api/v1/memories/protection')
            ->assertJsonPath('data.protection.upload_failed', 1)
            ->assertJsonPath('data.protection.state', 'needs_attention');
    }

    public function test_b_backup_failure_keeps_primary_retries_and_never_claims_protected(): void
    {
        $photo = $this->photo(['backup_status' => 'pending'], backup: false);
        $this->app->instance('photos.backup', $this->brokenStore('photos_backup', ['putObject']));

        $job = new BackupMemoryPhoto($photo->id);
        $this->assertSame([60, 300, 900, 3600], $job->backoff());
        $this->assertSame(5, $job->tries);

        try {
            $job->handle();
            $this->fail('Backup should have thrown so the queue retries it.');
        } catch (RuntimeException) {
        }

        $this->assertSame('backup_pending', $photo->refresh()->protectionStatus());
        Storage::disk('photos_primary')->assertExists($photo->storage_key);

        Log::spy();
        $job->failed(new RuntimeException('Connection refused.'));
        $this->assertSame('degraded', $photo->refresh()->protectionStatus());
        Log::shouldHaveReceived('error')->withArgs(fn ($message) => str_contains($message, 'backup failed'));
    }

    public function test_c_corrupt_primary_is_detected_verified_backup_restored_and_rechecked(): void
    {
        $photo = $this->photo();
        Storage::disk('photos_primary')->put($photo->storage_key, 'bit-rot');

        VerifyMemoryPhotoIntegrity::dispatchSync($photo->id);

        $photo->refresh();
        $this->assertSame('ok', $photo->primary_integrity);
        $this->assertSame($this->ciphertext, Storage::disk('photos_primary')->get($photo->storage_key));
        $this->assertSame('protected', $photo->protectionStatus());
        $this->assertSame('succeeded', PhotoStorageAudit::where('memory_photo_id', $photo->id)->where('action', 'repair')->value('result'));
    }

    public function test_d_corrupt_backup_never_overwrites_a_valid_primary(): void
    {
        $photo = $this->photo();
        Storage::disk('photos_backup')->put($photo->storage_key, 'bad-backup');
        Queue::fake([RepairMemoryPhoto::class]);
        Log::spy();

        VerifyMemoryPhotoIntegrity::dispatchSync($photo->id);

        $this->assertSame('mismatch', $photo->refresh()->backup_integrity);
        $this->assertSame($this->ciphertext, Storage::disk('photos_primary')->get($photo->storage_key));
        Log::shouldHaveReceived('warning')->withArgs(fn ($message) => str_contains($message, 'integrity problem'));
        $this->assertContains('integrity_mismatch', collect(app(\App\Services\Storage\StorageHealthService::class)->alerts())->pluck('code'));

        // The queued repair copies primary → backup, never the other way.
        Queue::assertPushed(RepairMemoryPhoto::class);
        (new RepairMemoryPhoto($photo->id))->handle();
        $this->assertSame($this->ciphertext, Storage::disk('photos_backup')->get($photo->storage_key));
        $this->assertSame($this->ciphertext, Storage::disk('photos_primary')->get($photo->storage_key));
    }

    public function test_e_both_copies_bad_keeps_metadata_claims_nothing_and_alerts(): void
    {
        $photo = $this->photo();
        Storage::disk('photos_primary')->put($photo->storage_key, 'bad-1');
        Storage::disk('photos_backup')->put($photo->storage_key, 'bad-2');
        $metadata = $photo->only(MemoryPhoto::DECRYPTION_METADATA);
        Log::spy();

        RepairMemoryPhoto::dispatchSync($photo->id);

        $photo->refresh();
        $this->assertSame('failed', $photo->repair_status);
        $this->assertSame('degraded', $photo->protectionStatus());
        $this->assertSame($metadata, $photo->only(MemoryPhoto::DECRYPTION_METADATA));
        $this->assertSame('bad-1', Storage::disk('photos_primary')->get($photo->storage_key));
        $this->assertNotSame('succeeded', PhotoStorageAudit::where('memory_photo_id', $photo->id)->value('result'));
        Log::shouldHaveReceived('critical')->withArgs(fn ($message) => str_contains($message, 'operator intervention'));
        $this->assertContains('repair_failed', collect(app(\App\Services\Storage\StorageHealthService::class)->alerts())->pluck('code'));
    }

    public function test_g_delete_during_backup_never_shows_protected_and_keeps_retention(): void
    {
        $photo = $this->photo(['backup_status' => 'pending'], backup: false);

        // The user trashes the photo while its backup job is queued.
        $this->actingAs($this->user)->deleteJson("/api/v1/memory-photos/{$photo->id}")->assertOk();
        BackupMemoryPhoto::dispatchSync($photo->id);

        $photo->refresh();
        $this->assertSame('verified', $photo->backup_status);
        $this->assertSame('deleted', $photo->protectionStatus());
        Storage::disk('photos_backup')->assertExists($photo->storage_key);

        // Retention still applies: not purged early, restorable within 30 days.
        PurgeMemoryPhoto::dispatchSync($photo->id);
        $this->assertNull($photo->refresh()->primary_purged_at);
        $this->actingAs($this->user)->postJson("/api/v1/memory-photos/{$photo->id}/restore")->assertOk();
        $this->assertSame('protected', $photo->refresh()->protectionStatus());
    }

    public function test_h_worker_crash_rerun_is_idempotent_and_overwrites_nothing(): void
    {
        $photo = $this->photo(['backup_status' => 'pending']);
        // Worker copied the object, then died before updating the database.
        $backupBefore = Storage::disk('photos_backup')->lastModified($photo->storage_key);

        $spy = Mockery::mock(FlysystemPhotoStorage::class, ['photos_backup'])->makePartial();
        $spy->shouldNotReceive('putObject');
        $this->app->instance('photos.backup', $spy);

        BackupMemoryPhoto::dispatchSync($photo->id);
        BackupMemoryPhoto::dispatchSync($photo->id);

        $this->assertSame('protected', $photo->refresh()->protectionStatus());
        $this->assertSame($backupBefore, Storage::disk('photos_backup')->lastModified($photo->storage_key));
        $this->assertSame(1, MemoryPhoto::count());
    }

    public function test_i_backup_account_unavailable_keeps_primary_records_degradation_and_alerts(): void
    {
        $photo = $this->photo(['backup_status' => 'pending'], backup: false);
        $this->app->instance('photos.backup', $this->brokenStore('photos_backup', ['getObjectMetadata', 'putObject', 'listKeys']));

        $job = new BackupMemoryPhoto($photo->id);
        try {
            $job->handle();
        } catch (RuntimeException) {
        }
        $job->failed(new RuntimeException('Connection refused.'));

        $photo->refresh();
        $this->assertSame('degraded', $photo->protectionStatus());
        $this->assertStringContainsString('Connection refused', $photo->backup_error);
        Storage::disk('photos_primary')->assertExists($photo->storage_key);
        $this->assertContains('backup_unreachable', collect(app(\App\Services\Storage\StorageHealthService::class)->alerts())->pluck('code'));

        // Users still get their photo (from the primary).
        $this->actingAs($this->user)->get("/api/v1/memory-photos/{$photo->id}/content")->assertOk();
    }

    public function test_j_missing_key_is_not_storage_corruption_and_server_never_decrypts(): void
    {
        // The couple lost every device and its Recovery Key: no key package exists for key-1.
        $photo = $this->photo();

        VerifyMemoryPhotoIntegrity::dispatchSync($photo->id);

        // Storage is healthy and stays "protected": copies are intact, only the key is gone.
        $this->assertSame('protected', $photo->refresh()->protectionStatus());
        $this->assertSame(0, PhotoStorageAudit::where('action', 'repair')->count());

        // The server hands out the same ciphertext it stored; it has nothing to decrypt with.
        $response = $this->actingAs($this->user)->get("/api/v1/memory-photos/{$photo->id}/content")->assertOk();
        $this->assertSame($this->ciphertext, $response->streamedContent());
        $this->assertSame('application/octet-stream', $response->headers->get('Content-Type'));
        // That no key material exists server-side is proven by EncryptionSecurityTest; the
        // client reports this case as CoupleKeyUnavailableException, not PhotoVerificationException
        // (memory_photo_repository_decrypt_test.dart: "another couple key is reported as key unavailable").
    }
}
