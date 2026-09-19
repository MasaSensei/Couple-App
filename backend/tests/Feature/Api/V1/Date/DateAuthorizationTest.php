<?php

namespace Tests\Feature\Api\V1\Date;

use App\Models\Couple;
use App\Models\Date;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DateAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_cannot_view_date_from_another_couple(): void
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

        $date = Date::factory()->create([
            'couple_id' => $coupleB->id,
            'created_by' => $userB->id,
        ]);

        Sanctum::actingAs($userA);

        $response = $this->getJson(
            "/api/v1/dates/{$date->id}"
        );

        $response
            ->assertStatus(404)
            ->assertJson([
                'success' => false,
                'message' => 'Date not found.',
            ]);
    }

    public function test_user_cannot_update_date_from_another_couple(): void
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

        $date = Date::factory()->create([
            'couple_id' => $coupleB->id,
            'created_by' => $userB->id,
        ]);

        Sanctum::actingAs($userA);

        $response = $this->patchJson(
            "/api/v1/dates/{$date->id}",
            [
                'title' => 'Hacked title',
            ],
        );

        $response
            ->assertStatus(404)
            ->assertJson([
                'success' => false,
                'message' => 'Date not found.',
            ]);

        $this->assertDatabaseHas('dates', [
            'id' => $date->id,
            'title' => $date->title,
        ]);
    }

    public function test_user_cannot_complete_date_from_another_couple(): void
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

        $date = Date::factory()->create([
            'couple_id' => $coupleB->id,
            'created_by' => $userB->id,
            'status' => 'planned',
        ]);

        Sanctum::actingAs($userA);

        $response = $this->postJson(
            "/api/v1/dates/{$date->id}/complete"
        );

        $response
            ->assertStatus(404)
            ->assertJson([
                'success' => false,
                'message' => 'Date not found.',
            ]);

        $this->assertDatabaseHas('dates', [
            'id' => $date->id,
            'status' => 'planned',
        ]);
    }

    public function test_user_cannot_cancel_date_from_another_couple(): void
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

        $date = Date::factory()->create([
            'couple_id' => $coupleB->id,
            'created_by' => $userB->id,
            'status' => 'planned',
        ]);

        Sanctum::actingAs($userA);

        $response = $this->postJson(
            "/api/v1/dates/{$date->id}/cancel"
        );

        $response
            ->assertStatus(404)
            ->assertJson([
                'success' => false,
                'message' => 'Date not found.',
            ]);

        $this->assertDatabaseHas('dates', [
            'id' => $date->id,
            'status' => 'planned',
        ]);
    }

    public function test_guest_cannot_access_date(): void
    {
        $user = User::factory()->create();
        $couple = Couple::factory()->create();

        $couple->members()->create([
            'user_id' => $user->id,
        ]);

        $date = Date::factory()->create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
        ]);

        $response = $this->getJson(
            "/api/v1/dates/{$date->id}"
        );

        $response->assertStatus(401);
    }

    public function test_user_without_couple_cannot_access_date(): void
    {
        $owner = User::factory()->create();

        $couple = Couple::factory()->create();

        $couple->members()->create([
            'user_id' => $owner->id,
        ]);

        $date = Date::factory()->create([
            'couple_id' => $couple->id,
            'created_by' => $owner->id,
        ]);

        $userWithoutCouple = User::factory()->create();

        Sanctum::actingAs($userWithoutCouple);

        $response = $this->getJson(
            "/api/v1/dates/{$date->id}"
        );

        $response
            ->assertStatus(404)
            ->assertJson([
                'success' => false,
                'message' => 'Date not found.',
            ]);
    }
}
