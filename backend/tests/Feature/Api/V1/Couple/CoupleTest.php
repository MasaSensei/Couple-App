<?php

namespace Tests\Feature\Api\V1\Couple;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CoupleTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_create_couple(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/couple');

        $response
            ->assertCreated()
            ->assertJsonStructure([
                'success',
                'message',
                'data' => [
                    'couple' => [
                        'id',
                        'invite_code',
                        'members',
                        'created_at',
                    ],
                ],
            ]);

        $this->assertDatabaseHas('couples', [
            'id' => $response->json('data.couple.id'),
        ]);

        $this->assertDatabaseHas('couple_members', [
            'couple_id' => $response->json('data.couple.id'),
            'user_id' => $user->id,
        ]);
    }

    public function test_user_cannot_create_second_couple(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        // Couple pertama
        $this->postJson('/api/v1/couple')
            ->assertCreated();

        // Mencoba membuat couple kedua
        $response = $this->postJson('/api/v1/couple');

        $response
            ->assertUnprocessable()
            ->assertJson([
                'success' => false,
                'message' => 'User already belongs to a couple.',
                'data' => null,
            ]);

        $this->assertDatabaseCount('couples', 1);

        $this->assertDatabaseCount('couple_members', 1);
    }

    public function test_user_can_join_couple_with_valid_invite_code(): void
    {
        $owner = User::factory()->create();
        $partner = User::factory()->create();

        Sanctum::actingAs($owner);

        $createResponse = $this->postJson('/api/v1/couple');

        $createResponse->assertCreated();

        $inviteCode = $createResponse->json('data.couple.invite_code');

        Sanctum::actingAs($partner);

        $response = $this->postJson('/api/v1/couple/join', [
            'invite_code' => $inviteCode,
        ]);

        $response
            ->assertOk()
            ->assertJson([
                'success' => true,
            ])
            ->assertJsonStructure([
                'data' => [
                    'couple' => [
                        'id',
                        'invite_code',
                        'members',
                    ],
                ],
            ]);

        $coupleId = $createResponse->json('data.couple.id');

        $this->assertDatabaseHas('couple_members', [
            'couple_id' => $coupleId,
            'user_id' => $owner->id,
        ]);

        $this->assertDatabaseHas('couple_members', [
            'couple_id' => $coupleId,
            'user_id' => $partner->id,
        ]);

        $this->assertDatabaseCount('couple_members', 2);
    }

    public function test_user_cannot_join_couple_with_invalid_invite_code(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/couple/join', [
            'invite_code' => 'INVALID8',
        ]);

        $response
            ->assertUnprocessable()
            ->assertJson([
                'success' => false,
                'message' => 'Invalid invite code.',
                'data' => null,
            ]);

        $this->assertDatabaseCount('couples', 0);
        $this->assertDatabaseCount('couple_members', 0);
    }

    public function test_user_cannot_join_full_couple(): void
    {
        $owner = User::factory()->create();
        $partner = User::factory()->create();
        $thirdUser = User::factory()->create();

        Sanctum::actingAs($owner);

        $createResponse = $this->postJson('/api/v1/couple');

        $createResponse->assertCreated();

        $inviteCode = $createResponse->json(
            'data.couple.invite_code'
        );

        // Member kedua
        Sanctum::actingAs($partner);

        $this->postJson('/api/v1/couple/join', [
            'invite_code' => $inviteCode,
        ])->assertOk();

        // Member ketiga
        Sanctum::actingAs($thirdUser);

        $response = $this->postJson('/api/v1/couple/join', [
            'invite_code' => $inviteCode,
        ]);

        $response
            ->assertUnprocessable()
            ->assertJson([
                'success' => false,
                'message' => 'This couple already has two members.',
                'data' => null,
            ]);

        $this->assertDatabaseCount('couple_members', 2);
    }

    public function test_join_couple_requires_invite_code(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/couple/join', []);

        $response
            ->assertUnprocessable()
            ->assertJson([
                'success' => false,
                'message' => 'The given data was invalid.',
            ])
            ->assertJsonStructure([
                'data' => [
                    'errors' => [
                        'invite_code',
                    ],
                ],
            ]);
    }

    public function test_guest_cannot_create_couple(): void
    {
        $response = $this->postJson('/api/v1/couple');

        $response
            ->assertUnauthorized()
            ->assertJson([
                'success' => false,
                'message' => 'Unauthenticated.',
                'data' => null,
            ]);
    }

    public function test_guest_cannot_join_couple(): void
    {
        $response = $this->postJson('/api/v1/couple/join', [
            'invite_code' => 'ABCDEFGH',
        ]);

        $response
            ->assertUnauthorized()
            ->assertJson([
                'success' => false,
                'message' => 'Unauthenticated.',
                'data' => null,
            ]);
    }
}
