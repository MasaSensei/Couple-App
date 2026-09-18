<?php

namespace Tests\Feature\Api\V1\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AuthenticationTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_access_me(): void
    {
        $user = User::factory()->create([
            'name' => 'Test User',
            'email' => 'auth@example.com',
        ]);

        Sanctum::actingAs($user);

        $response = $this->getJson('/api/v1/me');

        $response
            ->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'user' => [
                        'id' => $user->id,
                        'name' => 'Test User',
                        'email' => 'auth@example.com',
                    ],
                ],
            ]);
    }

    public function test_guest_cannot_access_me(): void
    {
        $response = $this->getJson('/api/v1/me');

        $response
            ->assertUnauthorized()
            ->assertJson([
                'success' => false,
            ]);
    }
}
