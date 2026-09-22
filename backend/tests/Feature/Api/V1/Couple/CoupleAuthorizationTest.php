<?php

namespace Tests\Feature\Api\V1\Couple;

use App\Models\Couple;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CoupleAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_cannot_view_another_couple(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();

        $coupleA = Couple::factory()->create();
        $coupleB = Couple::factory()->create();

        $coupleA->members()->create([
            'user_id' => $userA->id,
        ]);

        $coupleB->members()->create([
            'user_id' => $userB->id,
        ]);

        Sanctum::actingAs($userA);

        $response = $this->getJson(
            "/api/v1/couple/{$coupleB->id}"
        );

        $response
            ->assertStatus(403)
            ->assertJson([
                'success' => false,
                'message' => 'This action is unauthorized.',
            ]);
    }

    public function test_user_cannot_create_invitation_for_another_couple(): void
    {
        $userA = User::factory()->create();
        $userB = User::factory()->create();

        $coupleA = Couple::factory()->create();
        $coupleB = Couple::factory()->create();

        $coupleA->members()->create([
            'user_id' => $userA->id,
        ]);

        $coupleB->members()->create([
            'user_id' => $userB->id,
        ]);

        Sanctum::actingAs($userA);

        /*
         * The endpoint itself resolves the couple
         * from the authenticated user, so user A
         * can only create an invitation for Couple A.
         *
         * This assertion verifies that Couple B
         * receives no invitation from User A.
         */
        $response = $this->postJson(
            '/api/v1/couple/invite'
        );

        $response->assertStatus(201);

        $this->assertDatabaseMissing(
            'couple_invitations',
            [
                'couple_id' => $coupleB->id,
                'invited_by' => $userA->id,
            ],
        );

        $this->assertDatabaseHas(
            'couple_invitations',
            [
                'couple_id' => $coupleA->id,
                'invited_by' => $userA->id,
            ],
        );
    }

    public function test_guest_cannot_view_couple(): void
    {
        $user = User::factory()->create();

        $couple = Couple::factory()->create();

        $couple->members()->create([
            'user_id' => $user->id,
        ]);

        $response = $this->getJson(
            "/api/v1/couple/{$couple->id}"
        );

        $response->assertStatus(401);
    }

    public function test_guest_cannot_create_invitation(): void
    {
        $response = $this->postJson(
            '/api/v1/couple/invite'
        );

        $response->assertStatus(401);
    }
}
