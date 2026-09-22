<?php

namespace Tests\Feature\Api\V1\Couple;

use App\Models\Couple;
use App\Models\CoupleInvitation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CoupleInvitationSecurityTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_without_couple_can_accept_valid_invitation(): void
    {
        $owner = User::factory()->create();
        $invitee = User::factory()->create();

        $couple = Couple::factory()->create();

        $couple->members()->create([
            'user_id' => $owner->id,
        ]);

        $invitation = CoupleInvitation::factory()->create([
            'couple_id' => $couple->id,
            'invited_by' => $owner->id,
            'status' => 'pending',
            'expires_at' => now()->addDays(7),
        ]);

        Sanctum::actingAs($invitee);

        $response = $this->postJson(
            "/api/v1/couple/invite/{$invitation->token}/accept"
        );

        $response
            ->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Invitation accepted successfully.',
            ]);

        $this->assertDatabaseHas('couple_members', [
            'couple_id' => $couple->id,
            'user_id' => $invitee->id,
        ]);

        $this->assertDatabaseHas('couple_invitations', [
            'id' => $invitation->id,
            'status' => 'accepted',
        ]);
    }

    public function test_user_already_in_couple_cannot_accept_invitation(): void
    {
        $ownerA = User::factory()->create();
        $ownerB = User::factory()->create();
        $invitee = User::factory()->create();

        $coupleA = Couple::factory()->create();
        $coupleB = Couple::factory()->create();

        $coupleA->members()->create([
            'user_id' => $ownerA->id,
        ]);

        $coupleA->members()->create([
            'user_id' => $invitee->id,
        ]);

        $coupleB->members()->create([
            'user_id' => $ownerB->id,
        ]);

        $invitation = CoupleInvitation::factory()->create([
            'couple_id' => $coupleB->id,
            'invited_by' => $ownerB->id,
            'status' => 'pending',
            'expires_at' => now()->addDays(7),
        ]);

        Sanctum::actingAs($invitee);

        $response = $this->postJson(
            "/api/v1/couple/invite/{$invitation->token}/accept"
        );

        $response
            ->assertStatus(422)
            ->assertJson([
                'success' => false,
                'message' => 'User already belongs to a couple.',
            ]);

        $this->assertDatabaseMissing('couple_members', [
            'couple_id' => $coupleB->id,
            'user_id' => $invitee->id,
        ]);

        $this->assertDatabaseHas('couple_invitations', [
            'id' => $invitation->id,
            'status' => 'pending',
        ]);
    }

    public function test_expired_invitation_cannot_be_accepted(): void
    {
        $owner = User::factory()->create();
        $invitee = User::factory()->create();

        $couple = Couple::factory()->create();

        $couple->members()->create([
            'user_id' => $owner->id,
        ]);

        $invitation = CoupleInvitation::factory()->create([
            'couple_id' => $couple->id,
            'invited_by' => $owner->id,
            'status' => 'pending',
            'expires_at' => now()->subMinute(),
        ]);

        Sanctum::actingAs($invitee);

        $response = $this->postJson(
            "/api/v1/couple/invite/{$invitation->token}/accept"
        );

        $response
            ->assertStatus(422)
            ->assertJson([
                'success' => false,
                'message' => 'This invitation has expired.',
            ]);

        $this->assertDatabaseHas('couple_invitations', [
            'id' => $invitation->id,
            'status' => 'expired',
        ]);

        $this->assertDatabaseMissing('couple_members', [
            'couple_id' => $couple->id,
            'user_id' => $invitee->id,
        ]);
    }

    public function test_accepted_invitation_cannot_be_used_again(): void
    {
        $owner = User::factory()->create();
        $invitee = User::factory()->create();

        $couple = Couple::factory()->create();

        $couple->members()->create([
            'user_id' => $owner->id,
        ]);

        $couple->members()->create([
            'user_id' => $invitee->id,
        ]);

        $invitation = CoupleInvitation::factory()->create([
            'couple_id' => $couple->id,
            'invited_by' => $owner->id,
            'status' => 'accepted',
            'expires_at' => now()->addDays(7),
            'accepted_at' => now(),
        ]);

        /*
         * Use a third user so the failure comes
         * from the invitation status itself.
         */
        $anotherUser = User::factory()->create();

        Sanctum::actingAs($anotherUser);

        $response = $this->postJson(
            "/api/v1/couple/invite/{$invitation->token}/accept"
        );

        $response
            ->assertStatus(422)
            ->assertJson([
                'success' => false,
                'message' => 'This invitation is no longer active.',
            ]);

        $this->assertDatabaseMissing('couple_members', [
            'couple_id' => $couple->id,
            'user_id' => $anotherUser->id,
        ]);
    }

    public function test_guest_cannot_accept_invitation(): void
    {
        $owner = User::factory()->create();

        $couple = Couple::factory()->create();

        $couple->members()->create([
            'user_id' => $owner->id,
        ]);

        $invitation = CoupleInvitation::factory()->create([
            'couple_id' => $couple->id,
            'invited_by' => $owner->id,
            'status' => 'pending',
            'expires_at' => now()->addDays(7),
        ]);

        $memberCountBefore = $couple->members()->count();

        $response = $this->postJson(
            "/api/v1/couple/invite/{$invitation->token}/accept"
        );

        $response->assertStatus(401);

        $this->assertSame(
            $memberCountBefore,
            $couple->members()->count(),
        );

        $this->assertDatabaseHas('couple_invitations', [
            'id' => $invitation->id,
            'status' => 'pending',
        ]);
    }
}
