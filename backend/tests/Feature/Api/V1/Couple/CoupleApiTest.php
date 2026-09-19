<?php

namespace Tests\Feature\Api\V1\Couple;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CoupleApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_create_couple(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/couple');

        $response
            ->assertCreated()
            ->assertJson([
                'success' => true,
                'message' => 'Couple created successfully.',
            ]);

        $this->assertDatabaseHas('couples', [
            'id' => $response->json('data.couple.id'),
        ]);

        $this->assertDatabaseHas('couple_members', [
            'couple_id' => $response->json('data.couple.id'),
            'user_id' => $user->id,
        ]);
    }

    public function test_user_can_get_their_couple(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $this->postJson('/api/v1/couple')
            ->assertCreated();

        $response = $this->getJson('/api/v1/couple');

        $response
            ->assertOk()
            ->assertJson([
                'success' => true,
                'message' => 'Couple retrieved successfully.',
            ]);

        $response->assertJsonPath(
            'data.couple.members.0.id',
            $user->id
        );
    }

    public function test_user_without_couple_gets_not_found(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $response = $this->getJson('/api/v1/couple');

        $response
            ->assertNotFound()
            ->assertJson([
                'success' => false,
                'message' => 'User does not belong to a couple.',
                'data' => null,
            ]);
    }

    public function test_user_can_join_couple_using_invite_code(): void
    {
        $owner = User::factory()->create();
        $guest = User::factory()->create();

        Sanctum::actingAs($owner);

        $createResponse = $this->postJson('/api/v1/couple');

        $createResponse->assertCreated();

        $inviteCode = $createResponse->json(
            'data.couple.invite_code'
        );

        Sanctum::actingAs($guest);

        $response = $this->postJson(
            '/api/v1/couple/join',
            [
                'invite_code' => $inviteCode,
            ]
        );

        $response
            ->assertOk()
            ->assertJson([
                'success' => true,
                'message' => 'Successfully joined the couple.',
            ]);

        $this->assertDatabaseHas('couple_members', [
            'user_id' => $guest->id,
            'couple_id' => $createResponse->json(
                'data.couple.id'
            ),
        ]);
    }

    public function test_user_cannot_join_non_existing_couple(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $response = $this->postJson(
            '/api/v1/couple/join',
            [
                'invite_code' => 'INVALID1',
            ]
        );

        $response
            ->assertUnprocessable()
            ->assertJson([
                'success' => false,
                'message' => 'Invalid invite code.',
                'data' => null,
            ]);
    }

    public function test_couple_cannot_have_more_than_two_members(): void
    {
        $owner = User::factory()->create();
        $partner = User::factory()->create();
        $thirdUser = User::factory()->create();

        Sanctum::actingAs($owner);

        $createResponse = $this->postJson(
            '/api/v1/couple'
        );

        $createResponse->assertCreated();

        $inviteCode = $createResponse->json(
            'data.couple.invite_code'
        );

        Sanctum::actingAs($partner);

        $this->postJson(
            '/api/v1/couple/join',
            [
                'invite_code' => $inviteCode,
            ]
        )->assertOk();

        Sanctum::actingAs($thirdUser);

        $response = $this->postJson(
            '/api/v1/couple/join',
            [
                'invite_code' => $inviteCode,
            ]
        );

        $response
            ->assertUnprocessable()
            ->assertJson([
                'success' => false,
                'message' => 'This couple already has two members.',
                'data' => null,
            ]);
    }
}
