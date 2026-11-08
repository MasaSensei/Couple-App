<?php

namespace Tests\Feature\Storage;

use App\Jobs\PurgeMemoryPhoto;
use App\Jobs\RepairMemoryPhoto;
use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\PhotoStorageAudit;
use App\Models\User;
use App\Services\Memory\MemoryPhotoService;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class PhotoRetentionTest extends TestCase
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

        $this->ciphertext = random_bytes(2048);

        $this->user = User::factory()->create();
        $couple = Couple::factory()->create();
        CoupleMember::create(['couple_id' => $couple->id, 'user_id' => $this->user->id]);
        $this->memory = Memory::factory()->create(['couple_id' => $couple->id, 'created_by' => $this->user->id]);
    }

    private function photo(array $attributes = []): MemoryPhoto
    {
        $photo = (new MemoryPhoto)->forceFill([
            'memory_id' => $this->memory->id,
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

    private function trashedDaysAgo(MemoryPhoto $photo, int $days): MemoryPhoto
    {
        $photo->delete();
        $photo->forceFill(['deleted_at' => now()->subDays($days)])->save();

        return $photo->refresh();
    }

    public function test_user_delete_moves_photo_to_trash_and_touches_no_object(): void
    {
        $photo = $this->photo();

        $this->actingAs($this->user)
            ->deleteJson("/api/v1/memory-photos/{$photo->id}")
            ->assertOk()
            ->assertJsonPath('data.restorable_until', fn ($value) => $value !== null);

        $this->assertSoftDeleted('memory_photos', ['id' => $photo->id]);
        Storage::disk('photos_primary')->assertExists($photo->storage_key);
        Storage::disk('photos_backup')->assertExists($photo->storage_key);
        $this->assertDatabaseHas('photo_storage_audits', [
            'memory_photo_id' => $photo->id, 'action' => 'trash', 'actor' => "user:{$this->user->id}",
        ]);

        // Hidden from normal views.
        $this->actingAs($this->user)
            ->getJson("/api/v1/memories/{$this->memory->id}/photos")
            ->assertJsonCount(0, 'data.photos');
        $this->actingAs($this->user)
            ->get("/api/v1/memory-photos/{$photo->id}/content")
            ->assertNotFound();
    }

    public function test_trash_lists_restorable_photos_only(): void
    {
        $recent = $this->trashedDaysAgo($this->photo(), 1);
        $this->trashedDaysAgo($this->photo(), 31);
        $this->photo(); // live

        $this->actingAs($this->user)
            ->getJson("/api/v1/memories/{$this->memory->id}/photos/trash")
            ->assertOk()
            ->assertJsonCount(1, 'data.photos')
            ->assertJsonPath('data.photos.0.id', $recent->id);
    }

    public function test_restore_within_retention_brings_photo_back_and_reverifies_primary(): void
    {
        $photo = $this->trashedDaysAgo($this->photo(), 5);

        $this->actingAs($this->user)
            ->postJson("/api/v1/memory-photos/{$photo->id}/restore")
            ->assertOk()
            ->assertJsonPath('data.photo.id', $photo->id);

        $photo->refresh();
        $this->assertFalse($photo->trashed());
        $this->assertSame('ok', $photo->primary_integrity);
        $this->assertSame('protected', $photo->protectionStatus());
        $this->assertDatabaseHas('photo_storage_audits', ['memory_photo_id' => $photo->id, 'action' => 'restore']);
    }

    public function test_restore_with_missing_primary_queues_repair_instead_of_claiming_healthy(): void
    {
        Queue::fake();
        $photo = $this->trashedDaysAgo($this->photo(), 5);
        Storage::disk('photos_primary')->delete($photo->storage_key);

        $this->actingAs($this->user)
            ->postJson("/api/v1/memory-photos/{$photo->id}/restore")
            ->assertOk();

        $photo->refresh();
        $this->assertSame('missing', $photo->primary_integrity);
        $this->assertSame('restoring', $photo->protectionStatus());
        Queue::assertPushed(RepairMemoryPhoto::class, fn ($job) => $job->photoId === $photo->id);
    }

    public function test_restore_after_retention_is_refused(): void
    {
        $photo = $this->trashedDaysAgo($this->photo(), 31);

        $this->actingAs($this->user)
            ->postJson("/api/v1/memory-photos/{$photo->id}/restore")
            ->assertForbidden();

        $this->assertSoftDeleted('memory_photos', ['id' => $photo->id]);
    }

    public function test_other_couple_cannot_see_trash_or_restore(): void
    {
        $photo = $this->trashedDaysAgo($this->photo(), 1);
        $outsider = User::factory()->create();
        CoupleMember::create(['couple_id' => Couple::factory()->create()->id, 'user_id' => $outsider->id]);

        $this->actingAs($outsider)
            ->getJson("/api/v1/memories/{$this->memory->id}/photos/trash")
            ->assertForbidden();
        $this->actingAs($outsider)
            ->postJson("/api/v1/memory-photos/{$photo->id}/restore")
            ->assertForbidden();

        $this->assertSoftDeleted('memory_photos', ['id' => $photo->id]);
    }

    public function test_photo_of_a_deleted_memory_cannot_be_restored_alone(): void
    {
        $photo = $this->photo();

        $this->actingAs($this->user)
            ->deleteJson("/api/v1/memories/{$this->memory->id}")
            ->assertOk();

        $this->assertSoftDeleted('memory_photos', ['id' => $photo->id]);
        Storage::disk('photos_primary')->assertExists($photo->storage_key);

        $this->actingAs($this->user)
            ->postJson("/api/v1/memory-photos/{$photo->id}/restore")
            ->assertForbidden();
    }

    public function test_purge_waits_for_trash_retention(): void
    {
        $photo = $this->trashedDaysAgo($this->photo(), 29);

        PurgeMemoryPhoto::dispatchSync($photo->id);

        $this->assertNull($photo->refresh()->primary_purged_at);
        Storage::disk('photos_primary')->assertExists($photo->storage_key);
    }

    public function test_purge_stage_one_removes_primary_and_keeps_backup_and_metadata(): void
    {
        $photo = $this->trashedDaysAgo($this->photo(), 31);

        $this->artisan('photos:purge')->assertSuccessful();

        $photo->refresh();
        $this->assertNotNull($photo->primary_purged_at);
        $this->assertSame('deleted', $photo->protectionStatus());
        Storage::disk('photos_primary')->assertMissing($photo->storage_key);
        Storage::disk('photos_backup')->assertExists($photo->storage_key);
        $this->assertDatabaseHas('photo_storage_audits', ['memory_photo_id' => $photo->id, 'action' => 'purge_primary']);

        // Integrity and repair must not resurrect a purged copy.
        $this->artisan('photos:verify-integrity')->assertSuccessful();
        RepairMemoryPhoto::dispatchSync($photo->id);
        Storage::disk('photos_primary')->assertMissing($photo->storage_key);
        $this->assertNull($photo->refresh()->primary_integrity);
    }

    public function test_purge_stage_two_removes_backup_and_row_after_backup_retention(): void
    {
        $photo = $this->trashedDaysAgo($this->photo(), 70);
        $photo->forceFill(['primary_purged_at' => now()->subDays(31)])->save();

        $this->artisan('photos:purge')->assertSuccessful();

        Storage::disk('photos_backup')->assertMissing($photo->storage_key);
        $this->assertDatabaseMissing('memory_photos', ['id' => $photo->id]);
        // The audit trail outlives the row.
        $this->assertDatabaseHas('photo_storage_audits', ['action' => 'purge_backup', 'memory_photo_id' => null]);
    }

    public function test_backup_is_kept_during_backup_retention(): void
    {
        $photo = $this->trashedDaysAgo($this->photo(), 40);
        $photo->forceFill(['primary_purged_at' => now()->subDays(9)])->save();

        PurgeMemoryPhoto::dispatchSync($photo->id);

        Storage::disk('photos_backup')->assertExists($photo->storage_key);
        $this->assertDatabaseHas('memory_photos', ['id' => $photo->id]);
    }

    public function test_restore_and_purge_cannot_both_win(): void
    {
        $photo = $this->trashedDaysAgo($this->photo(), 31);

        PurgeMemoryPhoto::dispatchSync($photo->id);

        // Even bypassing the policy, the service's conditional update refuses.
        $this->expectException(\RuntimeException::class);
        app(MemoryPhotoService::class)->restore($photo->refresh(), $this->user);
    }

    public function test_restored_photo_is_never_purged(): void
    {
        $photo = $this->trashedDaysAgo($this->photo(), 31);
        $photo->restore();

        PurgeMemoryPhoto::dispatchSync($photo->id);

        Storage::disk('photos_primary')->assertExists($photo->storage_key);
        $this->assertNull($photo->refresh()->primary_purged_at);
    }

    public function test_abandoned_uploads_go_to_trash_not_straight_to_deletion(): void
    {
        $stale = $this->photo(['status' => 'pending', 'backup_status' => null]);
        $stale->forceFill(['created_at' => now()->subHours(25)])->save();
        $fresh = $this->photo(['status' => 'uploading', 'backup_status' => null]);

        $this->artisan('photos:purge')->assertSuccessful();

        $this->assertSoftDeleted('memory_photos', ['id' => $stale->id]);
        $this->assertNull($stale->refresh()->primary_purged_at);
        Storage::disk('photos_primary')->assertExists($stale->storage_key);
        $this->assertFalse($fresh->refresh()->trashed());
    }

    public function test_hard_deleting_a_user_keeps_their_memories_and_photos(): void
    {
        $photo = $this->photo();

        $this->user->delete();

        $this->assertDatabaseHas('memories', ['id' => $this->memory->id, 'created_by' => null]);
        $this->assertDatabaseHas('memory_photos', ['id' => $photo->id, 'uploaded_by' => null]);
    }

    public function test_hard_deleting_a_memory_with_photos_is_blocked(): void
    {
        $this->photo();

        $this->expectException(QueryException::class);
        $this->memory->forceDelete();
    }

    public function test_purge_audit_survives_and_records_failures(): void
    {
        $photo = $this->trashedDaysAgo($this->photo(), 31);

        (new PurgeMemoryPhoto($photo->id))->failed(new \RuntimeException('Connection refused.'));

        $this->assertSame('failed', PhotoStorageAudit::where('memory_photo_id', $photo->id)->value('result'));
    }
}
