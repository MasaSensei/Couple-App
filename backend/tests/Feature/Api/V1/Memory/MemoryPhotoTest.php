<?php

namespace Tests\Feature\Api\V1\Memory;

use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\Memory;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class MemoryPhotoTest extends TestCase
{
    use RefreshDatabase;

    public function test_plaintext_upload_without_encryption_metadata_is_rejected(): void
    {
        Storage::fake('local');

        $user = User::factory()->create();
        $couple = Couple::factory()->create();

        CoupleMember::create([
            'couple_id' => $couple->id,
            'user_id' => $user->id,
        ]);

        $memory = Memory::factory()->create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
        ]);

        $this->actingAs($user);

        $photoId = $this->postJson(
            "/api/v1/memories/{$memory->id}/photos/upload",
            [
                'mime_type' => 'image/jpeg',
                'file_size' => 100,
            ],
        )->assertCreated()->json('data.photo.id');

        $this->post(
            "/api/v1/memory-photos/{$photoId}/upload",
            ['photo' => UploadedFile::fake()->image('memory.jpg', 10, 10)],
        )->assertStatus(422);

        $this->assertSame([], Storage::disk('local')->allFiles());
    }

    public function test_user_can_list_verified_memory_photos(): void
    {
        $user = User::factory()->create();

        $couple = Couple::factory()->create();

        CoupleMember::create([
            'couple_id' => $couple->id,
            'user_id' => $user->id,
        ]);

        $memory = Memory::factory()->create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
        ]);

        $nonce = base64_encode(random_bytes(12));

        $photo = $memory->photos()->create([
            'uploaded_by' => $user->id,
            'storage_key' => 'couples/1/memories/1/photos/test.jpg',
            'original_filename' => 'test.jpg',
            'mime_type' => 'image/jpeg',
            'file_size' => 12345,
            'width' => 100,
            'height' => 100,
            'sort_order' => 0,
            'status' => 'verified',
            'encryption_version' => '1',
            'encryption_algorithm' => 'AES-256-GCM',
            'key_id' => 'test-key-id',
            'nonce' => $nonce,
            'encrypted_size' => 12345,
            'checksum' => str_repeat('a', 64),
        ]);

        $this->actingAs($user);

        $response = $this->getJson(
            "/api/v1/memories/{$memory->id}/photos",
        );

        $response
            ->assertOk()
            ->assertJsonPath(
                'data.photos.0.id',
                $photo->id,
            )
            ->assertJsonPath(
                'data.photos.0.status',
                'verified',
            )
            ->assertJsonPath(
                'data.photos.0.encryption_version',
                '1',
            )
            ->assertJsonPath(
                'data.photos.0.encryption_algorithm',
                'AES-256-GCM',
            )
            ->assertJsonPath(
                'data.photos.0.key_id',
                'test-key-id',
            )
            ->assertJsonPath(
                'data.photos.0.nonce',
                $nonce,
            );
    }

    public function test_unverified_memory_photos_are_not_listed(): void
    {
        $user = User::factory()->create();

        $couple = Couple::factory()->create();

        CoupleMember::create([
            'couple_id' => $couple->id,
            'user_id' => $user->id,
        ]);

        $memory = Memory::factory()->create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
        ]);

        $verifiedPhoto = $memory->photos()->create([
            'uploaded_by' => $user->id,
            'storage_key' => 'verified.jpg',
            'original_filename' => 'verified.jpg',
            'mime_type' => 'image/jpeg',
            'file_size' => 1000,
            'sort_order' => 0,
            'status' => 'verified',
        ]);

        $memory->photos()->create([
            'uploaded_by' => $user->id,
            'storage_key' => 'pending.jpg',
            'original_filename' => 'pending.jpg',
            'mime_type' => 'image/jpeg',
            'file_size' => 1000,
            'sort_order' => 1,
            'status' => 'pending',
        ]);

        $memory->photos()->create([
            'uploaded_by' => $user->id,
            'storage_key' => 'failed.jpg',
            'original_filename' => 'failed.jpg',
            'mime_type' => 'image/jpeg',
            'file_size' => 1000,
            'sort_order' => 2,
            'status' => 'failed',
        ]);

        $this->actingAs($user);

        $response = $this->getJson(
            "/api/v1/memories/{$memory->id}/photos",
        );

        $response
            ->assertOk()
            ->assertJsonCount(1, 'data.photos')
            ->assertJsonPath(
                'data.photos.0.id',
                $verifiedPhoto->id,
            );
    }

    public function test_user_from_another_couple_cannot_list_memory_photos(): void
    {
        $owner = User::factory()->create();
        $otherUser = User::factory()->create();

        $couple = Couple::factory()->create();

        CoupleMember::create([
            'couple_id' => $couple->id,
            'user_id' => $owner->id,
        ]);

        $memory = Memory::factory()->create([
            'couple_id' => $couple->id,
            'created_by' => $owner->id,
        ]);

        $memory->photos()->create([
            'uploaded_by' => $owner->id,
            'storage_key' => 'private.jpg',
            'original_filename' => 'private.jpg',
            'mime_type' => 'image/jpeg',
            'file_size' => 1000,
            'sort_order' => 0,
            'status' => 'verified',
        ]);

        $this->actingAs($otherUser);

        $response = $this->getJson(
            "/api/v1/memories/{$memory->id}/photos",
        );

        $response->assertForbidden();
    }
}
