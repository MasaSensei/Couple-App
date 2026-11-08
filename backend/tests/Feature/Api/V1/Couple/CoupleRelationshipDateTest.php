<?php

namespace Tests\Feature\Api\V1\Couple;

use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class CoupleRelationshipDateTest extends TestCase
{
    use RefreshDatabase;

    public function test_couple_resource_includes_the_optional_anniversary(): void
    {
        [$user] = $this->coupleWithMembers();

        $this->actingAs($user)->getJson('/api/v1/couple')
            ->assertOk()
            ->assertJsonPath('data.couple.relationship_started_at', null);
    }

    public function test_either_member_can_set_and_clear_it(): void
    {
        [$user, $partner, $couple] = $this->coupleWithMembers();

        $this->actingAs($partner)
            ->patchJson('/api/v1/couple', ['relationship_started_at' => '2025-09-22'])
            ->assertOk()
            ->assertJsonPath('data.couple.relationship_started_at', '2025-09-22');

        $this->actingAs($user)->getJson('/api/v1/couple')
            ->assertJsonPath('data.couple.relationship_started_at', '2025-09-22');

        $this->actingAs($user)
            ->patchJson('/api/v1/couple', ['relationship_started_at' => null])
            ->assertOk()
            ->assertJsonPath('data.couple.relationship_started_at', null);

        $this->assertNull($couple->fresh()->relationship_started_at);
    }

    public function test_future_and_malformed_dates_are_rejected(): void
    {
        [$user] = $this->coupleWithMembers();
        Carbon::setTestNow('2026-11-09');

        foreach (['2026-11-10', '22/09/2025', 'soon', '1850-01-01'] as $value) {
            $this->actingAs($user)
                ->patchJson('/api/v1/couple', ['relationship_started_at' => $value])
                ->assertUnprocessable()
                ->assertJsonStructure(['data' => ['errors' => ['relationship_started_at']]]);
        }

        $this->actingAs($user)->patchJson('/api/v1/couple', [])->assertUnprocessable();
    }

    public function test_invite_code_cannot_be_changed_through_this_endpoint(): void
    {
        [$user, , $couple] = $this->coupleWithMembers();
        $code = $couple->invite_code;

        $this->actingAs($user)->patchJson('/api/v1/couple', [
            'relationship_started_at' => '2025-01-01',
            'invite_code' => 'HACKED12',
        ])->assertOk();

        $this->assertSame($code, $couple->fresh()->invite_code);
    }

    public function test_user_without_couple_gets_404_and_guest_401(): void
    {
        $loner = User::factory()->create();

        $this->actingAs($loner)
            ->patchJson('/api/v1/couple', ['relationship_started_at' => '2025-01-01'])
            ->assertNotFound();

        $this->app['auth']->forgetGuards();
        $this->patchJson('/api/v1/couple', ['relationship_started_at' => '2025-01-01'])
            ->assertUnauthorized();
    }

    private function coupleWithMembers(): array
    {
        $user = User::factory()->create();
        $partner = User::factory()->create();
        $couple = Couple::create(['invite_code' => 'ABCD1234']);
        CoupleMember::create(['couple_id' => $couple->id, 'user_id' => $user->id]);
        CoupleMember::create(['couple_id' => $couple->id, 'user_id' => $partner->id]);

        return [$user, $partner, $couple];
    }
}
