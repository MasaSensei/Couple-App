<?php

namespace Tests\Feature\Api\V1\Couple;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;
use Illuminate\Support\Carbon;

class CoupleInvitationTest extends TestCase
{
    use RefreshDatabase;

    public function test_expired_invitation_cannot_be_retrieved(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $this->postJson('/api/v1/couple')
            ->assertCreated();

        $createResponse = $this->postJson(
            '/api/v1/couple/invite'
        );

        $createResponse->assertCreated();

        $invitationId = $createResponse->json(
            'data.invitation.id'
        );

        $token = $createResponse->json(
            'data.invitation.token'
        );

        \App\Models\CoupleInvitation::query()
            ->whereKey($invitationId)
            ->update([
                'expires_at' => Carbon::now()->subMinute(),
            ]);

        $response = $this->getJson(
            "/api/v1/couple/invite/{$token}"
        );

        $response
            ->assertUnprocessable()
            ->assertJson([
                'success' => false,
                'message' => 'This invitation has expired.',
                'data' => null,
            ]);

        $this->assertDatabaseHas('couple_invitations', [
            'id' => $invitationId,
            'status' => 'expired',
        ]);
    }

    public function test_couple_member_can_create_invitation(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $createResponse = $this->postJson('/api/v1/couple');

        $createResponse->assertCreated();

        $response = $this->postJson(
            '/api/v1/couple/invite'
        );

        $response
            ->assertCreated()
            ->assertJson([
                'success' => true,
                'message' => 'Couple invitation created successfully.',
                'data' => [
                    'invitation' => [
                        'status' => 'pending',
                    ],
                ],
            ]);

        $this->assertDatabaseHas('couple_invitations', [
            'status' => 'pending',
            'invited_by' => $user->id,
        ]);
    }

    public function test_user_without_couple_cannot_create_invitation(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $response = $this->postJson(
            '/api/v1/couple/invite'
        );

        $response
            ->assertNotFound()
            ->assertJson([
                'success' => false,
                'message' => 'User does not belong to a couple.',
                'data' => null,
            ]);
    }

    public function test_non_member_cannot_create_invitation_for_another_couple(): void
    {
        $owner = User::factory()->create();
        $nonMember = User::factory()->create();

        Sanctum::actingAs($owner);

        $createResponse = $this->postJson(
            '/api/v1/couple'
        );

        $createResponse->assertCreated();

        Sanctum::actingAs($nonMember);

        $response = $this->postJson(
            '/api/v1/couple/invite'
        );

        $response
            ->assertNotFound()
            ->assertJson([
                'success' => false,
                'message' => 'User does not belong to a couple.',
                'data' => null,
            ]);
    }

    public function test_invitation_can_be_retrieved_by_token(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $createCoupleResponse = $this->postJson(
            '/api/v1/couple'
        );

        $createCoupleResponse->assertCreated();

        $createInvitationResponse = $this->postJson(
            '/api/v1/couple/invite'
        );

        $createInvitationResponse->assertCreated();

        $token = $createInvitationResponse->json(
            'data.invitation.token'
        );

        $response = $this->getJson(
            "/api/v1/couple/invite/{$token}"
        );

        $response
            ->assertOk()
            ->assertJson([
                'success' => true,
                'message' => 'Invitation retrieved successfully.',
                'data' => [
                    'invitation' => [
                        'status' => 'pending',
                    ],
                ],
            ]);
    }

    public function test_invalid_invitation_token_returns_error(): void
    {
        $response = $this->getJson(
            '/api/v1/couple/invite/invalid-token'
        );

        $response
            ->assertUnprocessable()
            ->assertJson([
                'success' => false,
                'message' => 'Invalid invitation.',
                'data' => null,
            ]);
    }

    public function test_invitation_token_is_not_exposed_when_retrieving_invitation(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $this->postJson('/api/v1/couple')
            ->assertCreated();

        $createResponse = $this->postJson(
            '/api/v1/couple/invite'
        );

        $createResponse->assertCreated();

        $token = $createResponse->json(
            'data.invitation.token'
        );

        $response = $this->getJson(
            "/api/v1/couple/invite/{$token}"
        );

        $response
            ->assertOk()
            ->assertJsonMissingPath(
                'data.invitation.token'
            );
    }

    public function test_uses_testing_database(): void
    {
        $this->assertSame(
            'couples_test',
            config('database.connections.pgsql.database')
        );
    }

    public function test_user_can_accept_couple_invitation(): void
    {
        $owner = User::factory()->create();
        $guest = User::factory()->create();

        Sanctum::actingAs($owner);

        $createCoupleResponse = $this->postJson(
            '/api/v1/couple'
        );

        $createCoupleResponse->assertCreated();

        $coupleId = $createCoupleResponse->json(
            'data.couple.id'
        );

        Sanctum::actingAs($owner);

        $invitationResponse = $this->postJson(
            '/api/v1/couple/invite'
        );

        $invitationResponse->assertCreated();

        $token = $invitationResponse->json(
            'data.invitation.token'
        );

        Sanctum::actingAs($guest);

        $response = $this->postJson(
            "/api/v1/couple/invite/{$token}/accept"
        );

        $response
            ->assertOk()
            ->assertJson([
                'success' => true,
                'message' => 'Invitation accepted successfully.',
            ]);

        $this->assertDatabaseHas('couple_members', [
            'couple_id' => $coupleId,
            'user_id' => $guest->id,
        ]);

        $this->assertDatabaseHas('couple_invitations', [
            'token' => $token,
            'status' => 'accepted',
        ]);
    }
}
