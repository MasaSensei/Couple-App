<?php

namespace Tests\Feature\Api\V1\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RegisterTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_register(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Test User',
            'email' => 'register@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response
            ->assertCreated()
            ->assertJsonStructure([
                'success',
                'message',
                'data' => [
                    'user' => [
                        'id',
                        'name',
                        'email',
                        'email_verified_at',
                        'created_at',
                    ],
                    'token',
                ],
            ]);

        $this->assertDatabaseHas('users', [
            'email' => 'register@example.com',
            'name' => 'Test User',
        ]);

        $user = User::where(
            'email',
            'register@example.com'
        )->firstOrFail();

        $this->assertNotSame(
            'password123',
            $user->password
        );
    }

    public function test_user_cannot_register_with_existing_email(): void
    {
        User::factory()->create([
            'email' => 'existing@example.com',
        ]);

        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Another User',
            'email' => 'existing@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
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

        $this->assertDatabaseCount('users', 1);
    }

    public function test_registration_requires_valid_input(): void
    {
        $response = $this->postJson('/api/v1/auth/register', []);

        $response
            ->assertUnprocessable()
            ->assertJson([
                'success' => false,
                'message' => 'The given data was invalid.',
            ])
            ->assertJsonStructure([
                'data' => [
                    'errors' => [
                        'name',
                        'email',
                        'password',
                    ],
                ],
            ]);

        $this->assertDatabaseCount('users', 0);
    }
}
