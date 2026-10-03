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

    public function test_user_can_upload_memory_photo(): void
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
        $this->assertTrue(
            $user->can('view', $memory),
        );

        // 1. Create fake photo
        $file = UploadedFile::fake()->image(
            'memory.jpg',
            100,
            100,
        );

        // 2. Create upload session
        $sessionResponse = $this->postJson(
            "/api/v1/memories/{$memory->id}/photos/upload",
            [
                'original_filename' => 'memory.jpg',
                'mime_type' => 'image/jpeg',
                'file_size' => $file->getSize(),
                'width' => 100,
                'height' => 100,
            ],
        );

        $sessionResponse->dump();

        $sessionResponse
            ->assertCreated()
            ->assertJsonPath(
                'data.photo.status',
                'pending',
            );

        $photoId = $sessionResponse
            ->json('data.photo.id');

        // 3. Upload binary photo
        $uploadResponse = $this->post(
            "/api/v1/memory-photos/{$photoId}/upload",
            [
                'photo' => $file,
            ],
        );

        $uploadResponse
            ->assertOk()
            ->assertJsonPath(
                'data.photo.status',
                'uploading',
            );

        // 4. Complete upload
        $completeResponse = $this->postJson(
            "/api/v1/memory-photos/{$photoId}/complete",
        );

        $completeResponse
            ->assertOk()
            ->assertJsonPath(
                'data.photo.status',
                'verified',
            );

        // 5. Verify object exists
        $photo = $memory
            ->photos()
            ->findOrFail($photoId);

        $this->assertTrue(
            Storage::disk('local')->exists(
                $photo->storage_key,
            ),
        );

        // 6. Verify checksum exists
        $this->assertNotNull(
            $photo->checksum,
        );
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
            ->assertJsonMissingPath(
                'data.photos.0.storage_key',
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
