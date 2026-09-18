<?php

namespace Tests\Feature\Api\V1\User;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProfileTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_update_profile(): void
    {
        $user = User::factory()->create([
            'name' => 'Old Name',
            'email' => 'old@example.com',
        ]);

        Sanctum::actingAs($user);

        $response = $this->patchJson('/api/v1/me', [
            'name' => 'New Name',
            'email' => 'new@example.com',
        ]);

        $response
            ->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'user' => [
                        'id' => $user->id,
                        'name' => 'New Name',
                        'email' => 'new@example.com',
                    ],
                ],
            ]);

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'name' => 'New Name',
            'email' => 'new@example.com',
        ]);
    }

    public function test_guest_cannot_update_profile(): void
    {
        $response = $this->patchJson('/api/v1/me', [
            'name' => 'New Name',
        ]);

        $response
            ->assertUnauthorized()
            ->assertJson([
                'success' => false,
            ]);
    }

    public function test_user_cannot_update_profile_with_existing_email(): void
    {
        $user = User::factory()->create([
            'email' => 'user1@example.com',
        ]);

        User::factory()->create([
            'email' => 'user2@example.com',
        ]);

        Sanctum::actingAs($user);

        $response = $this->patchJson('/api/v1/me', [
            'email' => 'user2@example.com',
        ]);

        $response
            ->assertUnprocessable()
            ->assertJson([
                'success' => false,
                'message' => 'The given data was invalid.',
            ])
            ->assertJsonStructure([
                'data' => [
                    'errors' => [
                        'email',
                    ],
                ],
            ]);

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'email' => 'user1@example.com',
        ]);
    }

    public function test_user_can_keep_existing_email(): void
    {
        $user = User::factory()->create([
            'name' => 'Old Name',
            'email' => 'user@example.com',
        ]);

        Sanctum::actingAs($user);

        $response = $this->patchJson('/api/v1/me', [
            'name' => 'New Name',
            'email' => 'user@example.com',
        ]);

        $response
            ->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'user' => [
                        'id' => $user->id,
                        'name' => 'New Name',
                        'email' => 'user@example.com',
                    ],
                ],
            ]);

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'name' => 'New Name',
            'email' => 'user@example.com',
        ]);
    }
}
