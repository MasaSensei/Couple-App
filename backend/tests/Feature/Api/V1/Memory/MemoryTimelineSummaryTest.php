<?php

namespace Tests\Feature\Api\V1\Memory;

use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/** Timeline cards show a cover photo and a photo count (additive fields). */
class MemoryTimelineSummaryTest extends TestCase
{
    use RefreshDatabase;

    public function test_timeline_includes_cover_photo_metadata_and_visible_count(): void
    {
        [$user, $couple] = $this->coupleWithUser();
        $memory = $this->memory($couple, $user, 'Sunset walk');

        $this->photo($memory, $user, sortOrder: 2);
        $cover = $this->photo($memory, $user, sortOrder: 1);
        $this->photo($memory, $user, sortOrder: 0, status: 'pending');
        $trashed = $this->photo($memory, $user, sortOrder: 0);
        $trashed->delete();

        $response = $this->actingAs($user)->getJson('/api/v1/memories/timeline')->assertOk();

        $response
            ->assertJsonPath('data.memories.0.photos_count', 2)
            ->assertJsonPath('data.memories.0.cover_photo.id', $cover->id)
            ->assertJsonPath('data.memories.0.cover_photo.nonce', 'bm9uY2U=')
            ->assertJsonPath('data.memories.0.cover_photo.key_id', 'key-1');

        // Ciphertext metadata only: never a storage path or a public URL.
        $json = json_encode($response->json('data.memories.0.cover_photo'));
        $this->assertStringNotContainsString('storage_key', $json);
        $this->assertStringNotContainsString('test/', $json);
        $this->assertStringNotContainsString('http', $json);
    }

    public function test_memory_without_photos_has_null_cover_and_zero_count(): void
    {
        [$user, $couple] = $this->coupleWithUser();
        $this->memory($couple, $user, 'Words only');

        $this->actingAs($user)->getJson('/api/v1/memories')
            ->assertOk()
            ->assertJsonPath('data.memories.0.photos_count', 0)
            ->assertJsonPath('data.memories.0.cover_photo', null);
    }

    public function test_cover_photos_load_without_n_plus_one_queries(): void
    {
        [$user, $couple] = $this->coupleWithUser();
        for ($i = 0; $i < 12; $i++) {
            $memory = $this->memory($couple, $user, "Memory {$i}");
            $this->photo($memory, $user);
        }

        DB::enableQueryLog();
        $this->actingAs($user)->getJson('/api/v1/memories/timeline?per_page=20')->assertOk();
        $memoryPhotoQueries = collect(DB::getQueryLog())
            ->filter(fn ($q) => str_contains($q['query'], 'memory_photos'))
            ->count();

        // One query for the counts (part of the main query) and one for covers.
        $this->assertLessThanOrEqual(2, $memoryPhotoQueries);
    }

    public function test_other_couples_photos_never_become_a_cover(): void
    {
        [$user, $couple] = $this->coupleWithUser();
        [$other, $otherCouple] = $this->coupleWithUser();
        $mine = $this->memory($couple, $user, 'Mine');
        $theirs = $this->memory($otherCouple, $other, 'Theirs');
        $this->photo($theirs, $other);

        $this->actingAs($user)->getJson('/api/v1/memories/timeline')
            ->assertOk()
            ->assertJsonCount(1, 'data.memories')
            ->assertJsonPath('data.memories.0.id', $mine->id)
            ->assertJsonPath('data.memories.0.cover_photo', null);
    }

    private function coupleWithUser(): array
    {
        $user = User::factory()->create();
        $couple = Couple::create();
        CoupleMember::create(['couple_id' => $couple->id, 'user_id' => $user->id]);

        return [$user, $couple];
    }

    private function memory(Couple $couple, User $user, string $title): Memory
    {
        return Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => $title,
            'memory_date' => '2026-11-06',
        ]);
    }

    private function photo(Memory $memory, User $user, int $sortOrder = 0, string $status = 'verified'): MemoryPhoto
    {
        return MemoryPhoto::create([
            'memory_id' => $memory->id,
            'uploaded_by' => $user->id,
            'storage_key' => 'test/'.uniqid().'.bin',
            'mime_type' => 'image/jpeg',
            'file_size' => 10,
            'status' => $status,
            'sort_order' => $sortOrder,
            'encryption_version' => 1,
            'encryption_algorithm' => 'AES-256-GCM',
            'key_id' => 'key-1',
            'nonce' => 'bm9uY2U=',
            'mac' => 'bWFj',
            'encrypted_size' => 42,
        ]);
    }
}
