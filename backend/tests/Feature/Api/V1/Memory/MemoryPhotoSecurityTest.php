<?php

namespace Tests\Feature\Api\V1\Memory;

use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\Date;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class MemoryPhotoSecurityTest extends TestCase
{
    use RefreshDatabase;

    private function createCoupleWithUser(): array
    {
        $user = User::factory()->create();

        $couple = Couple::create();

        CoupleMember::create([
            'couple_id' => $couple->id,
            'user_id' => $user->id,
        ]);

        return [$user, $couple];
    }

    public function test_couple_member_can_access_verified_photo(): void
    {
        [$user, $couple] = $this->createCoupleWithUser();

        $memory = Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'Test Memory',
            'memory_date' => '2026-09-20',
        ]);

        $photo = MemoryPhoto::create([
            'memory_id' => $memory->id,
            'uploaded_by' => $user->id,
            'storage_key' => 'test/photo.jpg',
            'mime_type' => 'image/jpeg',
            'file_size' => 10,
            'status' => 'verified',
        ]);

        Storage::disk('local')->put(
            'test/photo.jpg',
            'test image',
        );

        $response = $this->actingAs($user)
            ->get(
                "/api/v1/memory-photos/{$photo->id}/content"
            );

        $response->assertOk();
    }

    public function test_non_member_cannot_access_photo(): void
    {
        [$owner, $couple] = $this->createCoupleWithUser();

        $otherUser = User::factory()->create();

        $memory = Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $owner->id,
            'title' => 'Private Memory',
            'memory_date' => '2026-09-20',
        ]);

        $photo = MemoryPhoto::create([
            'memory_id' => $memory->id,
            'uploaded_by' => $owner->id,
            'storage_key' => 'test/private.jpg',
            'mime_type' => 'image/jpeg',
            'file_size' => 10,
            'status' => 'verified',
        ]);

        Storage::disk('local')->put(
            'test/private.jpg',
            'private image',
        );

        $response = $this->actingAs($otherUser)
            ->get(
                "/api/v1/memory-photos/{$photo->id}/content"
            );

        $response->assertForbidden();
    }

    public function test_guest_cannot_access_photo(): void
    {
        [$user, $couple] = $this->createCoupleWithUser();

        $memory = Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'Private Memory',
            'memory_date' => '2026-09-20',
        ]);

        $photo = MemoryPhoto::create([
            'memory_id' => $memory->id,
            'uploaded_by' => $user->id,
            'storage_key' => 'test/private.jpg',
            'mime_type' => 'image/jpeg',
            'file_size' => 10,
            'status' => 'verified',
        ]);

        Storage::disk('local')->put(
            'test/private.jpg',
            'private image',
        );

        $response = $this->get(
            "/api/v1/memory-photos/{$photo->id}/content"
        );

        $response->assertUnauthorized();
    }

    public function test_pending_photo_cannot_be_accessed(): void
    {
        [$user, $couple] = $this->createCoupleWithUser();

        $memory = Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'Pending Memory',
            'memory_date' => '2026-09-20',
        ]);

        $photo = MemoryPhoto::create([
            'memory_id' => $memory->id,
            'uploaded_by' => $user->id,
            'storage_key' => 'test/pending.jpg',
            'mime_type' => 'image/jpeg',
            'file_size' => 10,
            'status' => 'pending',
        ]);

        Storage::disk('local')->put(
            'test/pending.jpg',
            'pending image',
        );

        $response = $this->actingAs($user)
            ->get(
                "/api/v1/memory-photos/{$photo->id}/content"
            );

        $response->assertForbidden();
    }

    public function test_deleted_photo_cannot_be_accessed(): void
    {
        [$user, $couple] = $this->createCoupleWithUser();

        $memory = Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'Deleted Memory',
            'memory_date' => '2026-09-20',
        ]);

        $photo = MemoryPhoto::create([
            'memory_id' => $memory->id,
            'uploaded_by' => $user->id,
            'storage_key' => 'test/deleted.jpg',
            'mime_type' => 'image/jpeg',
            'file_size' => 10,
            'status' => 'verified',
        ]);

        Storage::disk('local')->put(
            'test/deleted.jpg',
            'deleted image',
        );

        $photo->delete();

        $response = $this->actingAs($user)
            ->get(
                "/api/v1/memory-photos/{$photo->id}/content"
            );

        $response->assertNotFound();
    }
}
