<?php

namespace Tests\Feature\Api\V1\Date;

use App\Models\Couple;
use App\Models\Date;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DateCommentAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_cannot_view_comments_from_another_couple(): void
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

        $date->comments()->create([
            'user_id' => $userB->id,
            'content' => 'Private comment.',
        ]);

        Sanctum::actingAs($userA);

        $response = $this->getJson(
            "/api/v1/dates/{$date->id}/comments"
        );

        $response
            ->assertStatus(404)
            ->assertJson([
                'success' => false,
                'message' => 'Date not found.',
            ]);
    }

    public function test_user_cannot_create_comment_on_date_from_another_couple(): void
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

        $response = $this->postJson(
            "/api/v1/dates/{$date->id}/comments",
            [
                'content' => 'Unauthorized comment.',
            ],
        );

        $response
            ->assertStatus(404)
            ->assertJson([
                'success' => false,
                'message' => 'Date not found.',
            ]);

        $this->assertDatabaseMissing('date_comments', [
            'date_id' => $date->id,
            'user_id' => $userA->id,
            'content' => 'Unauthorized comment.',
        ]);
    }

    public function test_guest_cannot_access_date_comments(): void
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
            "/api/v1/dates/{$date->id}/comments"
        );

        $response->assertStatus(401);
    }

    public function test_guest_cannot_create_date_comment(): void
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

        $response = $this->postJson(
            "/api/v1/dates/{$date->id}/comments",
            [
                'content' => 'Unauthorized comment.',
            ],
        );

        $response->assertStatus(401);
    }

    public function test_user_without_couple_cannot_access_date_comments(): void
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
            "/api/v1/dates/{$date->id}/comments"
        );

        $response
            ->assertStatus(404)
            ->assertJson([
                'success' => false,
                'message' => 'Date not found.',
            ]);
    }

    public function test_user_without_couple_cannot_create_date_comment(): void
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

        $response = $this->postJson(
            "/api/v1/dates/{$date->id}/comments",
            [
                'content' => 'Unauthorized comment.',
            ],
        );

        $response
            ->assertStatus(404)
            ->assertJson([
                'success' => false,
                'message' => 'Date not found.',
            ]);

        $this->assertDatabaseMissing('date_comments', [
            'date_id' => $date->id,
            'user_id' => $userWithoutCouple->id,
            'content' => 'Unauthorized comment.',
        ]);
    }
}
