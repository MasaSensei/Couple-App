<?php

namespace Tests\Feature\Api\V1\Date;

use App\Models\Couple;
use App\Models\Date;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DateCommentApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_member_can_get_date_comments(): void
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

        $date->comments()->create([
            'user_id' => $user->id,
            'content' => 'This was such a lovely day.',
        ]);

        Sanctum::actingAs($user);

        $response = $this->getJson(
            "/api/v1/dates/{$date->id}/comments"
        );

        $response
            ->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Date comments retrieved successfully.',
            ])
            ->assertJsonCount(
                1,
                'data.comments',
            );

        $response->assertJsonPath(
            'data.comments.0.content',
            'This was such a lovely day.',
        );

        $response->assertJsonPath(
            'data.comments.0.user.id',
            $user->id,
        );
    }

    public function test_member_can_create_date_comment(): void
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

        Sanctum::actingAs($user);

        $response = $this->postJson(
            "/api/v1/dates/{$date->id}/comments",
            [
                'content' => 'I really enjoyed this date.',
            ],
        );

        $response
            ->assertStatus(201)
            ->assertJson([
                'success' => true,
                'message' => 'Date comment created successfully.',
            ]);

        $response->assertJsonPath(
            'data.comment.content',
            'I really enjoyed this date.',
        );

        $response->assertJsonPath(
            'data.comment.date_id',
            $date->id,
        );

        $response->assertJsonPath(
            'data.comment.user_id',
            $user->id,
        );

        $this->assertDatabaseHas('date_comments', [
            'date_id' => $date->id,
            'user_id' => $user->id,
            'content' => 'I really enjoyed this date.',
        ]);
    }

    public function test_member_can_create_multiple_comments(): void
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

        Sanctum::actingAs($user);

        $this->postJson(
            "/api/v1/dates/{$date->id}/comments",
            [
                'content' => 'First comment.',
            ],
        )->assertStatus(201);

        $this->postJson(
            "/api/v1/dates/{$date->id}/comments",
            [
                'content' => 'Second comment.',
            ],
        )->assertStatus(201);

        $this->assertDatabaseCount(
            'date_comments',
            2,
        );
    }

    public function test_comment_content_is_required(): void
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

        Sanctum::actingAs($user);

        $response = $this->postJson(
            "/api/v1/dates/{$date->id}/comments",
            []
        );

        $response
            ->assertStatus(422)
            ->assertJson([
                'success' => false,
            ]);

        $this->assertDatabaseCount(
            'date_comments',
            0,
        );
    }

    public function test_comment_content_cannot_exceed_5000_characters(): void
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

        Sanctum::actingAs($user);

        $response = $this->postJson(
            "/api/v1/dates/{$date->id}/comments",
            [
                'content' => str_repeat('a', 5001),
            ],
        );

        $response
            ->assertStatus(422)
            ->assertJson([
                'success' => false,
            ]);

        $this->assertDatabaseCount(
            'date_comments',
            0,
        );
    }
}
