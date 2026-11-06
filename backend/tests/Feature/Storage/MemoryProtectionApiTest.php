<?php

namespace Tests\Feature\Storage;

use App\Models\Couple;
use App\Models\CoupleKeyPackage;
use App\Models\CoupleMember;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\User;
use App\Models\UserDevice;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MemoryProtectionApiTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    private Memory $memory;

    protected function setUp(): void
    {
        parent::setUp();

        [$this->user, $this->memory] = $this->coupleWithMemory();
    }

    private function coupleWithMemory(): array
    {
        $user = User::factory()->create();
        $couple = Couple::factory()->create();
        CoupleMember::create(['couple_id' => $couple->id, 'user_id' => $user->id]);

        return [$user, Memory::factory()->create(['couple_id' => $couple->id, 'created_by' => $user->id])];
    }

    private function photo(array $attributes = [], ?Memory $memory = null): MemoryPhoto
    {
        $photo = (new MemoryPhoto)->forceFill([
            'memory_id' => ($memory ?? $this->memory)->id,
            'storage_key' => 'k/'.fake()->uuid(),
            'mime_type' => 'image/jpeg',
            'file_size' => 10,
            'checksum' => str_repeat('a', 64),
            'encryption_version' => '1', 'key_id' => 'k', 'nonce' => 'n', 'mac' => 'm',
            'status' => 'verified',
            'backup_status' => 'verified',
            'integrity_checked_at' => now()->subHour(),
            'backup_verified_at' => now()->subMinutes(30),
            ...$attributes,
        ]);
        $photo->save();

        return $photo;
    }

    public function test_summary_reports_real_state_and_never_claims_protected_while_backing_up(): void
    {
        $this->photo();
        $this->photo();
        $this->photo(['backup_status' => 'pending', 'backup_verified_at' => null]);
        $this->photo(['status' => 'uploading', 'backup_status' => null]);
        $this->photo(['deleted_at' => now()]);

        $this->actingAs($this->user)
            ->getJson('/api/v1/memories/protection')
            ->assertOk()
            ->assertJsonPath('data.protection.photos', 3)
            ->assertJsonPath('data.protection.protected', 2)
            ->assertJsonPath('data.protection.backing_up', 1)
            ->assertJsonPath('data.protection.uploading', 1)
            ->assertJsonPath('data.protection.needs_attention', 0)
            ->assertJsonPath('data.protection.state', 'backing_up')
            ->assertJsonPath('data.protection.last_verified_backup_at', fn ($value) => $value !== null);
    }

    public function test_any_problem_turns_the_summary_to_needs_attention(): void
    {
        $this->photo();
        $this->photo(['primary_integrity' => 'mismatch']);

        $this->actingAs($this->user)
            ->getJson('/api/v1/memories/protection')
            ->assertJsonPath('data.protection.state', 'needs_attention')
            ->assertJsonPath('data.protection.needs_attention', 1);
    }

    public function test_all_protected_and_empty_states(): void
    {
        $this->actingAs($this->user)->getJson('/api/v1/memories/protection')
            ->assertJsonPath('data.protection.state', 'empty');

        $this->photo();

        $this->actingAs($this->user)->getJson('/api/v1/memories/protection')
            ->assertJsonPath('data.protection.state', 'protected');
    }

    public function test_summary_only_counts_the_users_own_couple(): void
    {
        [, $otherMemory] = $this->coupleWithMemory();
        $this->photo(['primary_integrity' => 'missing'], $otherMemory);
        $this->photo();

        $this->actingAs($this->user)
            ->getJson('/api/v1/memories/protection')
            ->assertJsonPath('data.protection.photos', 1)
            ->assertJsonPath('data.protection.state', 'protected');
    }

    public function test_photo_resource_exposes_user_facing_status_without_infrastructure_details(): void
    {
        $this->photo(['backup_status' => 'pending', 'backup_error' => 'S3Exception: http://storage-backup:8333 denied']);

        $response = $this->actingAs($this->user)
            ->getJson("/api/v1/memories/{$this->memory->id}/photos")
            ->assertOk()
            ->assertJsonPath('data.photos.0.protection_status', 'backing_up');

        foreach (['backup_error', 'storage_key', 'storage-backup', 'primary_integrity', 'repair_status'] as $leak) {
            $this->assertStringNotContainsString($leak, $response->getContent());
        }
    }

    public function test_guest_and_coupleless_user_get_no_summary(): void
    {
        $this->getJson('/api/v1/memories/protection')->assertUnauthorized();

        $this->actingAs(User::factory()->create())
            ->getJson('/api/v1/memories/protection')
            ->assertNotFound();
    }

    public function test_client_cannot_set_protection_through_any_request(): void
    {
        $device = UserDevice::create([
            'user_id' => $this->user->id, 'device_identifier' => 'd1', 'platform' => 'android', 'public_key' => base64_encode(random_bytes(32)),
        ]);
        (new CoupleKeyPackage)->forceFill([
            'couple_id' => $this->memory->couple_id, 'device_id' => $device->id, 'key_id' => 'key-1', 'encryption_version' => 1,
            'ephemeral_public_key' => 'e', 'nonce' => 'n', 'ciphertext' => 'c', 'mac' => 'm',
        ])->save();
        $photo = $this->photo(['status' => 'pending', 'backup_status' => null, 'checksum' => null, 'mac' => null, 'nonce' => null]);

        // The metadata update itself is valid, so the extra fields really reach mass assignment.
        $this->actingAs($this->user)->patchJson("/api/v1/memory-photos/{$photo->id}/encryption", [
            'encryption_version' => 1,
            'encryption_algorithm' => 'AES-256-GCM',
            'key_id' => 'key-1',
            'nonce' => base64_encode(random_bytes(12)),
            'mac' => base64_encode(random_bytes(16)),
            'encrypted_size' => 100,
            'checksum' => str_repeat('b', 64),
            // Attempted overrides:
            'status' => 'verified',
            'backup_status' => 'verified',
            'primary_integrity' => 'ok',
            'protection_status' => 'protected',
        ])->assertOk();

        $photo->refresh();
        $this->assertSame('key-1', $photo->key_id);
        $this->assertSame('pending', $photo->status);
        $this->assertNull($photo->backup_status);
        $this->assertSame('pending_upload', $photo->protectionStatus());
    }
}
