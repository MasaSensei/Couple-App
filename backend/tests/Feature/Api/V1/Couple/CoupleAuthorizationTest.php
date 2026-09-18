<?php

namespace Tests\Feature\Api\V1\Couple;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CoupleAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    public function test_couple_member_can_view_couple(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $createResponse = $this->postJson('/api/v1/couple');

        $createResponse->assertCreated();

        $coupleId = $createResponse->json(
            'data.couple.id'
        );

        $response = $this->getJson(
            "/api/v1/couple/{$coupleId}"
        );

        $response
            ->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'couple' => [
                        'id' => $coupleId,
                    ],
                ],
            ]);
    }

    public function test_non_member_cannot_view_couple(): void
    {
        $owner = User::factory()->create();
        $nonMember = User::factory()->create();

        Sanctum::actingAs($owner);

        $createResponse = $this->postJson('/api/v1/couple');

        $createResponse->assertCreated();

        $coupleId = $createResponse->json(
            'data.couple.id'
        );

        Sanctum::actingAs($nonMember);

        $response = $this->getJson(
            "/api/v1/couple/{$coupleId}"
        );

        $response->assertStatus(403);
    }

    public function test_guest_cannot_view_couple(): void
    {
        $owner = User::factory()->create();

        Sanctum::actingAs($owner);

        $createResponse = $this->postJson('/api/v1/couple');

        $createResponse->assertCreated();

        $coupleId = $createResponse->json(
            'data.couple.id'
        );

        // Clear authentication state.
        // Request berikutnya harus dianggap sebagai guest.
        $this->app['auth']->forgetGuards();

        $response = $this->getJson(
            "/api/v1/couple/{$coupleId}"
        );

        $response
            ->assertUnauthorized()
            ->assertJson([
                'success' => false,
                'message' => 'Unauthenticated.',
                'data' => null,
            ]);
    }

    public function test_non_existing_couple_returns_not_found(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $response = $this->getJson('/api/v1/couple/999999');

        $response
            ->assertNotFound()
            ->assertJson([
                'success' => false,
                'message' => 'Couple not found.',
                'data' => null,
            ]);
    }
}
