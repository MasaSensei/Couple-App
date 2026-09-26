<?php

namespace Tests\Feature\Api\V1\Memory;

use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\Memory;
use App\Models\MemoryComment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MemoryCommentTest extends TestCase
{
    use RefreshDatabase;

    /*
    |--------------------------------------------------------------------------
    | List
    |--------------------------------------------------------------------------
    */

    public function test_member_can_list_memory_comments(): void
    {
        [$user, $memory] = $this->createCoupleWithMemory();

        MemoryComment::create([
            'memory_id' => $memory->id,
            'user_id' => $user->id,
            'body' => 'Our first memory comment.',
        ]);

        $response = $this
            ->actingAs($user)
            ->get(
                "/api/v1/memories/{$memory->id}/comments",
            );

        $response
            ->assertOk()
            ->assertJsonPath(
                'data.comments.0.body',
                'Our first memory comment.',
            );
    }

    public function test_non_member_cannot_list_memory_comments(): void
    {
        [$owner, $memory] = $this->createCoupleWithMemory();

        $outsider = User::factory()->create();

        $response = $this
            ->actingAs($outsider)
            ->get(
                "/api/v1/memories/{$memory->id}/comments",
            );

        $response->assertForbidden();
    }

    public function test_guest_cannot_list_memory_comments(): void
    {
        [$user, $memory] = $this->createCoupleWithMemory();

        $response = $this->get(
            "/api/v1/memories/{$memory->id}/comments",
        );

        $response->assertUnauthorized();
    }

    /*
    |--------------------------------------------------------------------------
    | Create
    |--------------------------------------------------------------------------
    */

    public function test_member_can_create_memory_comment(): void
    {
        [$user, $memory] = $this->createCoupleWithMemory();

        $response = $this
            ->actingAs($user)
            ->postJson(
                "/api/v1/memories/{$memory->id}/comments",
                [
                    'body' => 'This is a beautiful memory.',
                ],
            );

        $response
            ->assertCreated()
            ->assertJsonPath(
                'data.comment.body',
                'This is a beautiful memory.',
            );

        $this->assertDatabaseHas(
            'memory_comments',
            [
                'memory_id' => $memory->id,
                'user_id' => $user->id,
                'body' => 'This is a beautiful memory.',
            ],
        );
    }

    public function test_non_member_cannot_create_memory_comment(): void
    {
        [$owner, $memory] = $this->createCoupleWithMemory();

        $outsider = User::factory()->create();

        $response = $this
            ->actingAs($outsider)
            ->postJson(
                "/api/v1/memories/{$memory->id}/comments",
                [
                    'body' => 'Unauthorized comment.',
                ],
            );

        $response->assertForbidden();

        $this->assertDatabaseMissing(
            'memory_comments',
            [
                'memory_id' => $memory->id,
                'user_id' => $outsider->id,
                'body' => 'Unauthorized comment.',
            ],
        );
    }

    public function test_guest_cannot_create_memory_comment(): void
    {
        [$user, $memory] = $this->createCoupleWithMemory();

        $response = $this
            ->postJson(
                "/api/v1/memories/{$memory->id}/comments",
                [
                    'body' => 'Guest comment.',
                ],
            );

        $response->assertUnauthorized();
    }

    /*
    |--------------------------------------------------------------------------
    | Create Validation
    |--------------------------------------------------------------------------
    */

    public function test_comment_body_is_required(): void
    {
        [$user, $memory] = $this->createCoupleWithMemory();

        $response = $this
            ->actingAs($user)
            ->postJson(
                "/api/v1/memories/{$memory->id}/comments",
                [],
            );

        $response->assertUnprocessable();
    }

    public function test_comment_body_must_be_string(): void
    {
        [$user, $memory] = $this->createCoupleWithMemory();

        $response = $this
            ->actingAs($user)
            ->postJson(
                "/api/v1/memories/{$memory->id}/comments",
                [
                    'body' => 12345,
                ],
            );

        $response->assertUnprocessable();
    }

    public function test_comment_body_cannot_exceed_5000_characters(): void
    {
        [$user, $memory] = $this->createCoupleWithMemory();

        $response = $this
            ->actingAs($user)
            ->postJson(
                "/api/v1/memories/{$memory->id}/comments",
                [
                    'body' => str_repeat('a', 5001),
                ],
            );

        $response->assertUnprocessable();
    }

    /*
    |--------------------------------------------------------------------------
    | Update
    |--------------------------------------------------------------------------
    */

    public function test_user_can_update_own_memory_comment(): void
    {
        [$user, $memory] = $this->createCoupleWithMemory();

        $comment = MemoryComment::create([
            'memory_id' => $memory->id,
            'user_id' => $user->id,
            'body' => 'Original comment.',
        ]);

        $response = $this
            ->actingAs($user)
            ->patchJson(
                "/api/v1/memory-comments/{$comment->id}",
                [
                    'body' => 'Updated comment.',
                ],
            );

        $response
            ->assertOk()
            ->assertJsonPath(
                'data.comment.body',
                'Updated comment.',
            );

        $this->assertDatabaseHas(
            'memory_comments',
            [
                'id' => $comment->id,
                'body' => 'Updated comment.',
            ],
        );
    }

    public function test_user_cannot_update_partner_memory_comment(): void
    {
        [$user, $memory] = $this->createCoupleWithMemory();

        $partner = User::factory()->create();

        CoupleMember::create([
            'couple_id' => $memory->couple_id,
            'user_id' => $partner->id,
        ]);

        $comment = MemoryComment::create([
            'memory_id' => $memory->id,
            'user_id' => $partner->id,
            'body' => 'Partner comment.',
        ]);

        $response = $this
            ->actingAs($user)
            ->patchJson(
                "/api/v1/memory-comments/{$comment->id}",
                [
                    'body' => 'Attempted modification.',
                ],
            );

        $response->assertForbidden();

        $this->assertDatabaseHas(
            'memory_comments',
            [
                'id' => $comment->id,
                'body' => 'Partner comment.',
            ],
        );
    }

    public function test_non_member_cannot_update_memory_comment(): void
    {
        [$user, $memory] = $this->createCoupleWithMemory();

        $comment = MemoryComment::create([
            'memory_id' => $memory->id,
            'user_id' => $user->id,
            'body' => 'Original comment.',
        ]);

        $outsider = User::factory()->create();

        $response = $this
            ->actingAs($outsider)
            ->patchJson(
                "/api/v1/memory-comments/{$comment->id}",
                [
                    'body' => 'Unauthorized modification.',
                ],
            );

        $response->assertForbidden();
    }

    public function test_guest_cannot_update_memory_comment(): void
    {
        [$user, $memory] = $this->createCoupleWithMemory();

        $comment = MemoryComment::create([
            'memory_id' => $memory->id,
            'user_id' => $user->id,
            'body' => 'Original comment.',
        ]);

        $response = $this->patchJson(
            "/api/v1/memory-comments/{$comment->id}",
            [
                'body' => 'Unauthorized modification.',
            ],
        );

        $response->assertUnauthorized();
    }

    /*
    |--------------------------------------------------------------------------
    | Delete
    |--------------------------------------------------------------------------
    */

    public function test_user_can_delete_own_memory_comment(): void
    {
        [$user, $memory] = $this->createCoupleWithMemory();

        $comment = MemoryComment::create([
            'memory_id' => $memory->id,
            'user_id' => $user->id,
            'body' => 'Comment to delete.',
        ]);

        $response = $this
            ->actingAs($user)
            ->deleteJson(
                "/api/v1/memory-comments/{$comment->id}",
            );

        $response->assertOk();

        $this->assertSoftDeleted(
            'memory_comments',
            [
                'id' => $comment->id,
            ],
        );
    }

    public function test_user_cannot_delete_partner_memory_comment(): void
    {
        [$user, $memory] = $this->createCoupleWithMemory();

        $partner = User::factory()->create();

        CoupleMember::create([
            'couple_id' => $memory->couple_id,
            'user_id' => $partner->id,
        ]);

        $comment = MemoryComment::create([
            'memory_id' => $memory->id,
            'user_id' => $partner->id,
            'body' => 'Partner comment.',
        ]);

        $response = $this
            ->actingAs($user)
            ->deleteJson(
                "/api/v1/memory-comments/{$comment->id}",
            );

        $response->assertForbidden();

        $this->assertDatabaseHas(
            'memory_comments',
            [
                'id' => $comment->id,
            ],
        );
    }

    public function test_non_member_cannot_delete_memory_comment(): void
    {
        [$user, $memory] = $this->createCoupleWithMemory();

        $comment = MemoryComment::create([
            'memory_id' => $memory->id,
            'user_id' => $user->id,
            'body' => 'Comment.',
        ]);

        $outsider = User::factory()->create();

        $response = $this
            ->actingAs($outsider)
            ->deleteJson(
                "/api/v1/memory-comments/{$comment->id}",
            );

        $response->assertForbidden();

        $this->assertDatabaseHas(
            'memory_comments',
            [
                'id' => $comment->id,
            ],
        );
    }

    public function test_guest_cannot_delete_memory_comment(): void
    {
        [$user, $memory] = $this->createCoupleWithMemory();

        $comment = MemoryComment::create([
            'memory_id' => $memory->id,
            'user_id' => $user->id,
            'body' => 'Comment.',
        ]);

        $response = $this->deleteJson(
            "/api/v1/memory-comments/{$comment->id}",
        );

        $response->assertUnauthorized();
    }

    /*
    |--------------------------------------------------------------------------
    | Cross Couple
    |--------------------------------------------------------------------------
    */

    public function test_user_from_another_couple_cannot_access_memory_comments(): void
    {
        [$owner, $memory] = $this->createCoupleWithMemory();

        MemoryComment::create([
            'memory_id' => $memory->id,
            'user_id' => $owner->id,
            'body' => 'Private couple comment.',
        ]);

        $outsider = User::factory()->create();

        $otherCouple = Couple::create();

        CoupleMember::create([
            'couple_id' => $otherCouple->id,
            'user_id' => $outsider->id,
        ]);

        $response = $this
            ->actingAs($outsider)
            ->get(
                "/api/v1/memories/{$memory->id}/comments",
            );

        $response->assertForbidden();
    }

    /*
    |--------------------------------------------------------------------------
    | Helpers
    |--------------------------------------------------------------------------
    */

    private function createCoupleWithMemory(): array
    {
        $user = User::factory()->create();

        $couple = Couple::create();

        CoupleMember::create([
            'couple_id' => $couple->id,
            'user_id' => $user->id,
        ]);

        $memory = Memory::create([
            'couple_id' => $couple->id,
            'created_by' => $user->id,
            'title' => 'Test Memory',
            'description' => 'Memory used for testing.',
            'memory_date' => '2026-09-20',
            'location_name' => 'Test Location',
            'location_address' => null,
            'latitude' => null,
            'longitude' => null,
        ]);

        return [$user, $memory];
    }
}
