<?php

namespace Tests\Feature\Api\V1\Date;

use App\Models\Couple;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DateApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_member_can_create_date(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $this->postJson('/api/v1/couple')
            ->assertCreated();

        $response = $this->postJson('/api/v1/dates', [
            'title' => 'Dinner together',
            'description' => 'Our first dinner date.',
            'location' => 'Jakarta',
            'scheduled_at' => now()
                ->addDays(3)
                ->toISOString(),
        ]);

        $response
            ->assertCreated()
            ->assertJson([
                'success' => true,
                'message' => 'Date created successfully.',
            ]);

        $this->assertDatabaseHas('dates', [
            'title' => 'Dinner together',
            'created_by' => $user->id,
            'status' => 'planned',
        ]);
    }

    public function test_user_without_couple_cannot_create_date(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/dates', [
            'title' => 'Dinner together',
            'scheduled_at' => now()
                ->addDays(3)
                ->toISOString(),
        ]);

        $response
            ->assertNotFound()
            ->assertJson([
                'success' => false,
                'message' => 'User does not belong to a couple.',
            ]);
    }

    public function test_member_can_get_dates(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $this->postJson('/api/v1/couple')
            ->assertCreated();

        $this->postJson('/api/v1/dates', [
            'title' => 'Movie night',
            'scheduled_at' => now()
                ->addDays(2)
                ->toISOString(),
        ])->assertCreated();

        $response = $this->getJson('/api/v1/dates');

        $response
            ->assertOk()
            ->assertJson([
                'success' => true,
                'message' => 'Dates retrieved successfully.',
            ])
            ->assertJsonCount(
                1,
                'data.dates'
            );
    }

    public function test_member_can_get_date_detail(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $this->postJson('/api/v1/couple')
            ->assertCreated();

        $createResponse = $this->postJson(
            '/api/v1/dates',
            [
                'title' => 'Beach date',
                'scheduled_at' => now()
                    ->addDays(5)
                    ->toISOString(),
            ],
        );

        $dateId = $createResponse->json(
            'data.date.id'
        );

        $response = $this->getJson(
            "/api/v1/dates/{$dateId}"
        );

        $response
            ->assertOk()
            ->assertJsonPath(
                'data.date.id',
                $dateId,
            );
    }

    public function test_member_can_update_date(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $this->postJson('/api/v1/couple')
            ->assertCreated();

        $createResponse = $this->postJson(
            '/api/v1/dates',
            [
                'title' => 'Old title',
                'scheduled_at' => now()
                    ->addDays(5)
                    ->toISOString(),
            ],
        );

        $dateId = $createResponse->json(
            'data.date.id'
        );

        $response = $this->patchJson(
            "/api/v1/dates/{$dateId}",
            [
                'title' => 'Updated title',
                'location' => 'Bandung',
            ],
        );

        $response
            ->assertOk()
            ->assertJson([
                'success' => true,
                'message' => 'Date updated successfully.',
            ]);

        $this->assertDatabaseHas('dates', [
            'id' => $dateId,
            'title' => 'Updated title',
            'location' => 'Bandung',
        ]);
    }

    public function test_member_can_complete_date(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $this->postJson('/api/v1/couple')
            ->assertCreated();

        $createResponse = $this->postJson(
            '/api/v1/dates',
            [
                'title' => 'Dinner',
                'scheduled_at' => now()
                    ->addDays(1)
                    ->toISOString(),
            ],
        );

        $dateId = $createResponse->json(
            'data.date.id'
        );

        $response = $this->postJson(
            "/api/v1/dates/{$dateId}/complete"
        );

        $response
            ->assertOk()
            ->assertJson([
                'success' => true,
                'message' => 'Date completed successfully.',
            ]);

        $this->assertDatabaseHas('dates', [
            'id' => $dateId,
            'status' => 'completed',
        ]);
    }

    public function test_member_can_cancel_date(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $this->postJson('/api/v1/couple')
            ->assertCreated();

        $createResponse = $this->postJson(
            '/api/v1/dates',
            [
                'title' => 'Cancelled plan',
                'scheduled_at' => now()
                    ->addDays(1)
                    ->toISOString(),
            ],
        );

        $dateId = $createResponse->json(
            'data.date.id'
        );

        $response = $this->postJson(
            "/api/v1/dates/{$dateId}/cancel"
        );

        $response
            ->assertOk()
            ->assertJson([
                'success' => true,
                'message' => 'Date cancelled successfully.',
            ]);

        $this->assertDatabaseHas('dates', [
            'id' => $dateId,
            'status' => 'cancelled',
        ]);
    }

    public function test_user_from_another_couple_cannot_access_date(): void
    {
        $owner = User::factory()->create();
        $otherUser = User::factory()->create();

        Sanctum::actingAs($owner);

        $this->postJson('/api/v1/couple')
            ->assertCreated();

        $createResponse = $this->postJson(
            '/api/v1/dates',
            [
                'title' => 'Private date',
                'scheduled_at' => now()
                    ->addDays(2)
                    ->toISOString(),
            ],
        );

        $dateId = $createResponse->json(
            'data.date.id'
        );

        Sanctum::actingAs($otherUser);

        $this->postJson('/api/v1/couple')
            ->assertCreated();

        $response = $this->getJson(
            "/api/v1/dates/{$dateId}"
        );

        $response
            ->assertUnprocessable()
            ->assertJson([
                'success' => false,
                'message' => 'Date not found.',
            ]);
    }

    public function test_cancelled_date_cannot_be_completed(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $this->postJson('/api/v1/couple')
            ->assertCreated();

        $createResponse = $this->postJson(
            '/api/v1/dates',
            [
                'title' => 'Cancelled date',
                'scheduled_at' => now()
                    ->addDays(2)
                    ->toISOString(),
            ],
        );

        $dateId = $createResponse->json(
            'data.date.id'
        );

        $this->postJson(
            "/api/v1/dates/{$dateId}/cancel"
        )->assertOk();

        $response = $this->postJson(
            "/api/v1/dates/{$dateId}/complete"
        );

        $response
            ->assertUnprocessable()
            ->assertJson([
                'success' => false,
                'message' => 'Cancelled date cannot be completed.',
            ]);
    }

    public function test_completed_date_cannot_be_cancelled(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $this->postJson('/api/v1/couple')
            ->assertCreated();

        $createResponse = $this->postJson(
            '/api/v1/dates',
            [
                'title' => 'Completed date',
                'scheduled_at' => now()
                    ->addDays(2)
                    ->toISOString(),
            ],
        );

        $dateId = $createResponse->json(
            'data.date.id'
        );

        $this->postJson(
            "/api/v1/dates/{$dateId}/complete"
        )->assertOk();

        $response = $this->postJson(
            "/api/v1/dates/{$dateId}/cancel"
        );

        $response
            ->assertUnprocessable()
            ->assertJson([
                'success' => false,
                'message' => 'Completed date cannot be cancelled.',
            ]);
    }
}
