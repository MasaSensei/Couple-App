<?php

namespace Tests\Feature\Api\V1\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class LogoutTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_logout(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/auth/logout');

        $response
            ->assertOk()
            ->assertJson([
                'success' => true,
            ]);
    }

    public function test_guest_cannot_logout(): void
    {
        $response = $this->postJson('/api/v1/auth/logout');

        $response
            ->assertUnauthorized()
            ->assertJson([
                'success' => false,
            ]);
    }

    public function test_token_cannot_be_used_after_logout(): void
    {
        $user = User::factory()->create();

        $token = $user->createToken('test-token')->plainTextToken;

        $this
            ->withToken($token)
            ->postJson('/api/v1/auth/logout')
            ->assertOk();

        $this->assertDatabaseCount('personal_access_tokens', 0);

        $this->app['auth']->forgetGuards();

        $response = $this
            ->withToken($token)
            ->getJson('/api/v1/me');

        $response
            ->assertUnauthorized()
            ->assertJson([
                'success' => false,
            ]);
    }
}
