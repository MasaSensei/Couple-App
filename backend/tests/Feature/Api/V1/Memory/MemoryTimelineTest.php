<?php

namespace Tests\Feature\Api\V1\Memory;

use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\Memory;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MemoryTimelineTest extends TestCase
{
    use RefreshDatabase;

    public function test_member_can_view_memory_timeline(): void
    {
        [$user, $couple] = $this->createCoupleWithUser();

        Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'First Memory',
            'memory_date' => '2026-09-20',
        ]);

        $response = $this
            ->actingAs($user)
            ->getJson(
                '/api/v1/memories/timeline',
            );

        $response
            ->assertOk()
            ->assertJsonPath(
                'data.memories.0.title',
                'First Memory',
            );
    }

    public function test_guest_cannot_view_memory_timeline(): void
    {
        $response = $this->getJson(
            '/api/v1/memories/timeline',
        );

        $response->assertUnauthorized();
    }

    public function test_user_only_sees_memories_from_own_couple(): void
    {
        [$user, $couple] = $this->createCoupleWithUser();

        Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'My Couple Memory',
            'memory_date' => '2026-09-20',
        ]);

        [$otherUser, $otherCouple] =
            $this->createCoupleWithUser();

        Memory::create([
            'couple_id' => $otherCouple->id,
            'created_by' => $otherUser->id,
            'title' => 'Other Couple Memory',
            'memory_date' => '2026-09-25',
        ]);

        $response = $this
            ->actingAs($user)
            ->getJson(
                '/api/v1/memories/timeline',
            );

        $response
            ->assertOk()
            ->assertJsonCount(
                1,
                'data.memories',
            )
            ->assertJsonPath(
                'data.memories.0.title',
                'My Couple Memory',
            );
    }

    public function test_timeline_is_sorted_by_memory_date_descending(): void
    {
        [$user, $couple] = $this->createCoupleWithUser();

        Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'Older Memory',
            'memory_date' => '2026-09-10',
        ]);

        Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'Newer Memory',
            'memory_date' => '2026-09-20',
        ]);

        $response = $this
            ->actingAs($user)
            ->getJson(
                '/api/v1/memories/timeline',
            );

        $response
            ->assertOk()
            ->assertJsonPath(
                'data.memories.0.title',
                'Newer Memory',
            )
            ->assertJsonPath(
                'data.memories.1.title',
                'Older Memory',
            );
    }

    public function test_same_memory_date_is_sorted_by_created_at_descending(): void
    {
        [$user, $couple] = $this->createCoupleWithUser();

        $older = Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'Created Earlier',
            'memory_date' => '2026-09-20',
        ]);

        $newer = Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'Created Later',
            'memory_date' => '2026-09-20',
        ]);

        $newer->created_at = now()->addMinute();
        $newer->save();

        $response = $this
            ->actingAs($user)
            ->getJson(
                '/api/v1/memories/timeline',
            );

        $response
            ->assertOk()
            ->assertJsonPath(
                'data.memories.0.id',
                $newer->id,
            )
            ->assertJsonPath(
                'data.memories.1.id',
                $older->id,
            );
    }

    public function test_deleted_memory_does_not_appear_in_timeline(): void
    {
        [$user, $couple] = $this->createCoupleWithUser();

        $active = Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'Active Memory',
            'memory_date' => '2026-09-20',
        ]);

        $deleted = Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'Deleted Memory',
            'memory_date' => '2026-09-25',
        ]);

        $deleted->delete();

        $response = $this
            ->actingAs($user)
            ->getJson(
                '/api/v1/memories/timeline',
            );

        $response
            ->assertOk()
            ->assertJsonCount(
                1,
                'data.memories',
            )
            ->assertJsonPath(
                'data.memories.0.id',
                $active->id,
            );
    }

    public function test_timeline_supports_pagination(): void
    {
        [$user, $couple] = $this->createCoupleWithUser();

        for ($i = 1; $i <= 5; $i++) {
            Memory::create([
                'couple_id' => $couple->id,
                'created_by' => $user->id,
                'title' => "Memory {$i}",
                'memory_date' => sprintf(
                    '2026-09-%02d',
                    $i,
                ),
            ]);
        }

        $response = $this
            ->actingAs($user)
            ->getJson(
                '/api/v1/memories/timeline?per_page=2',
            );

        $response
            ->assertOk()
            ->assertJsonCount(
                2,
                'data.memories',
            )
            ->assertJsonPath(
                'data.pagination.per_page',
                2,
            )
            ->assertJsonPath(
                'data.pagination.total',
                5,
            )
            ->assertJsonPath(
                'data.pagination.current_page',
                1,
            );
    }

    public function test_per_page_cannot_exceed_50(): void
    {
        [$user, $couple] = $this->createCoupleWithUser();

        $response = $this
            ->actingAs($user)
            ->getJson(
                '/api/v1/memories/timeline?per_page=999',
            );

        $response
            ->assertOk()
            ->assertJsonPath(
                'data.pagination.per_page',
                50,
            );
    }

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
}
