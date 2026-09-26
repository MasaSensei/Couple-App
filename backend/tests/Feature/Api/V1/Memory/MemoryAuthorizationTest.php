<?php

namespace Tests\Feature\Api\V1\Memory;

use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\Date;
use App\Models\Memory;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MemoryAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    public function test_couple_member_can_view_memory(): void
    {
        [$user, $couple] = $this->createCoupleWithUser();

        $memory = Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'Our First Memory',
            'memory_date' => '2026-09-20',
        ]);

        Sanctum::actingAs($user);

        $response = $this->getJson(
            "/api/v1/memories/{$memory->id}"
        );

        $response
            ->assertOk()
            ->assertJsonPath(
                'data.memory.id',
                $memory->id
            );
    }

    public function test_non_member_cannot_view_memory(): void
    {
        [$owner, $couple] = $this->createCoupleWithUser();

        $memory = Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $owner->id,
            'title' => 'Private Memory',
            'memory_date' => '2026-09-20',
        ]);

        [$otherUser] = $this->createCoupleWithUser();

        Sanctum::actingAs($otherUser);

        $response = $this->getJson(
            "/api/v1/memories/{$memory->id}"
        );

        $response->assertForbidden();
    }

    public function test_guest_cannot_view_memory(): void
    {
        [$user, $couple] = $this->createCoupleWithUser();

        $memory = Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'Private Memory',
            'memory_date' => '2026-09-20',
        ]);

        $response = $this->getJson(
            "/api/v1/memories/{$memory->id}"
        );

        $response->assertUnauthorized();
    }

    public function test_couple_member_can_update_memory(): void
    {
        [$user, $couple] = $this->createCoupleWithUser();

        $memory = Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'Old Title',
            'memory_date' => '2026-09-20',
        ]);

        Sanctum::actingAs($user);

        $response = $this->patchJson(
            "/api/v1/memories/{$memory->id}",
            [
                'title' => 'Updated Title',
            ]
        );

        $response
            ->assertOk()
            ->assertJsonPath(
                'data.memory.title',
                'Updated Title'
            );
    }

    public function test_non_member_cannot_update_memory(): void
    {
        [$owner, $couple] = $this->createCoupleWithUser();

        $memory = Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $owner->id,
            'title' => 'Private Memory',
            'memory_date' => '2026-09-20',
        ]);

        [$otherUser] = $this->createCoupleWithUser();

        Sanctum::actingAs($otherUser);

        $response = $this->patchJson(
            "/api/v1/memories/{$memory->id}",
            [
                'title' => 'Hacked Title',
            ]
        );

        $response->assertForbidden();

        $this->assertDatabaseHas('memories', [
            'id' => $memory->id,
            'title' => 'Private Memory',
        ]);
    }

    public function test_couple_member_can_delete_memory(): void
    {
        [$user, $couple] = $this->createCoupleWithUser();

        $memory = Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'Memory To Delete',
            'memory_date' => '2026-09-20',
        ]);

        Sanctum::actingAs($user);

        $response = $this->deleteJson(
            "/api/v1/memories/{$memory->id}"
        );

        $response->assertOk();

        $this->assertSoftDeleted('memories', [
            'id' => $memory->id,
        ]);
    }

    public function test_non_member_cannot_delete_memory(): void
    {
        [$owner, $couple] = $this->createCoupleWithUser();

        $memory = Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $owner->id,
            'title' => 'Protected Memory',
            'memory_date' => '2026-09-20',
        ]);

        [$otherUser] = $this->createCoupleWithUser();

        Sanctum::actingAs($otherUser);

        $response = $this->deleteJson(
            "/api/v1/memories/{$memory->id}"
        );

        $response->assertForbidden();

        $this->assertDatabaseHas('memories', [
            'id' => $memory->id,
            'deleted_at' => null,
        ]);
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

    public function test_user_only_sees_memories_from_their_couple(): void
    {
        [$userA, $coupleA] = $this->createCoupleWithUser();

        [$userB, $coupleB] = $this->createCoupleWithUser();

        Memory::create([
            'couple_id' => $coupleA->id,
            'created_by' => $userA->id,
            'title' => 'Couple A Memory',
            'memory_date' => '2026-09-20',
        ]);

        Memory::create([
            'couple_id' => $coupleB->id,
            'created_by' => $userB->id,
            'title' => 'Couple B Memory',
            'memory_date' => '2026-09-21',
        ]);

        Sanctum::actingAs($userA);

        $response = $this->getJson('/api/v1/memories');

        $response
            ->assertOk()
            ->assertJsonCount(1, 'data.memories')
            ->assertJsonPath(
                'data.memories.0.title',
                'Couple A Memory'
            );
    }

    public function test_memory_cannot_reference_date_from_another_couple(): void
    {
        [$userA, $coupleA] = $this->createCoupleWithUser();

        [$userB, $coupleB] = $this->createCoupleWithUser();

        $dateB = Date::create([
            'couple_id' => $coupleB->id,
            'created_by' => $userB->id,
            'title' => 'Couple B Date',
            'scheduled_at' => '2026-09-20 19:00:00',
            'status' => 'planned',
        ]);

        Sanctum::actingAs($userA);

        $response = $this->postJson(
            '/api/v1/memories',
            [
                'title' => 'Invalid Memory',
                'memory_date' => '2026-09-20',
                'date_id' => $dateB->id,
            ]
        );

        $response
            ->assertStatus(422)
            ->assertJsonPath(
                'message',
                'Date does not belong to this couple.'
            );

        $this->assertDatabaseMissing('memories', [
            'title' => 'Invalid Memory',
        ]);
    }

    public function test_memory_can_reference_date_from_same_couple(): void
    {
        [$user, $couple] = $this->createCoupleWithUser();

        $date = Date::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'Dinner Date',
            'scheduled_at' => '2026-09-20 19:00:00',
            'status' => 'planned',
        ]);

        Sanctum::actingAs($user);

        $response = $this->postJson(
            '/api/v1/memories',
            [
                'title' => 'Dinner Memory',
                'memory_date' => '2026-09-20',
                'date_id' => $date->id,
            ]
        );

        $response
            ->assertCreated()
            ->assertJsonPath(
                'data.memory.date_id',
                $date->id
            );
    }

    public function test_user_without_couple_cannot_create_memory(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $response = $this->postJson(
            '/api/v1/memories',
            [
                'title' => 'Orphan Memory',
                'memory_date' => '2026-09-20',
            ]
        );

        $response
            ->assertStatus(422)
            ->assertJsonPath(
                'message',
                'User does not belong to a couple.'
            );
    }

    public function test_memory_cannot_be_updated_to_date_from_another_couple(): void
    {
        [$userA, $coupleA] = $this->createCoupleWithUser();
        [$userB, $coupleB] = $this->createCoupleWithUser();

        $memory = Memory::factory()->create([
            'couple_id' => $coupleA->id,
            'created_by' => $userA->id,
            'date_id' => null,
        ]);

        $dateB = Date::factory()->create([
            'couple_id' => $coupleB->id,
            'created_by' => $userB->id,
        ]);

        $response = $this->actingAs($userA)
            ->patchJson(
                "/api/v1/memories/{$memory->id}",
                [
                    'date_id' => $dateB->id,
                ],
            );

        $response->assertStatus(422);
    }
}
