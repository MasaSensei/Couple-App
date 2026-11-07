<?php

namespace Tests\Feature\Billing;

use App\Models\Couple;
use App\Models\CoupleSubscription;
use App\Models\SubscriptionPlan;
use App\Models\Theme;
use App\Models\User;
use App\Services\Billing\EntitlementService;
use App\Services\Billing\PlanManagement;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class EntitlementTest extends TestCase
{
    use BillingHelpers, RefreshDatabase;

    private User $alice;

    private User $bob;

    private Couple $couple;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seedPlans();
        [$this->alice, $this->bob, $this->couple] = $this->makeCouple();
        Theme::where('key', 'cafe')->update(['is_premium' => true]);
        Theme::where('key', 'midnight')->update(['is_premium' => true]);
    }

    public function test_entitlements_belong_to_the_couple_only(): void
    {
        $this->buy($this->alice)->assertOk();

        [$carol, , $otherCouple] = $this->makeCouple();
        $loner = User::factory()->create();

        $this->actingAs($this->bob)->getJson('/api/v1/couple/entitlements')->assertJsonPath('data.entitlements.premium_themes', true);
        $this->actingAs($carol)->getJson('/api/v1/couple/entitlements')
            ->assertJsonPath('data.plan_key', 'free')
            ->assertJsonPath('data.entitlements.premium_themes', false);
        $this->actingAs($loner)->getJson('/api/v1/couple/entitlements')->assertNotFound();
        $this->actingAs($loner)->getJson('/api/v1/couple/subscription')->assertNotFound();
        $this->assertFalse(app(EntitlementService::class)->forCouple($otherCouple)->allows('premium_themes'));
    }

    public function test_client_cannot_fake_a_premium_status(): void
    {
        // Made-up token plus client-claimed status/amount/expiry: all ignored, nothing granted.
        $this->actingAs($this->alice)->postJson('/api/v1/couple/subscription/verify', [
            'provider' => 'mock',
            'product_id' => 'love_monthly',
            'purchase_token' => 'forged-token',
            'status' => 'active',
            'amount' => 0,
            'current_period_end' => '2099-01-01',
            'plan_key' => 'together_plus',
        ])->assertStatus(422)->assertJsonPath('data.code', 'purchase_invalid');

        // Not-yet-integrated stores fail closed.
        $this->actingAs($this->alice)->postJson('/api/v1/couple/subscription/verify', [
            'provider' => 'google_play', 'product_id' => 'love_monthly', 'purchase_token' => 'x',
        ])->assertStatus(422)->assertJsonPath('data.code', 'provider_unavailable');

        $this->assertSame(0, CoupleSubscription::count());
        $this->actingAs($this->alice)->getJson('/api/v1/couple/entitlements')->assertJsonPath('data.plan_key', 'free');
    }

    public function test_premium_themes_are_enforced_by_the_server_and_kept_after_expiry(): void
    {
        $catalog = $this->actingAs($this->alice)->getJson('/api/v1/appearance/catalog')->json('data.themes');
        $this->assertTrue(collect($catalog)->firstWhere('key', 'cafe')['locked']);
        $this->assertFalse(collect($catalog)->firstWhere('key', 'sakura')['locked']);

        $this->actingAs($this->alice)->putJson('/api/v1/couple/theme', ['theme_key' => 'cafe', 'customization' => [], 'version' => 0])
            ->assertForbidden()->assertJsonPath('data.code', 'entitlement_required')->assertJsonPath('data.entitlement', 'premium_themes');

        $this->buy($this->alice);
        $this->assertFalse(collect($this->actingAs($this->bob)->getJson('/api/v1/appearance/catalog')->json('data.themes'))->firstWhere('key', 'cafe')['locked']);
        $this->actingAs($this->bob)->putJson('/api/v1/couple/theme', ['theme_key' => 'cafe', 'customization' => [], 'version' => 0])->assertOk();

        // Subscription ends: the chosen premium theme stays (and can be tweaked), but no new premium switch.
        $subscription = $this->liveSubscription($this->couple);
        $this->travelTo($subscription->current_period_end->copy()->addDays(3));
        $this->actingAs($this->bob)->getJson('/api/v1/couple/theme')->assertJsonPath('data.theme.theme_key', 'cafe');
        $this->actingAs($this->bob)->putJson('/api/v1/couple/theme', ['theme_key' => 'cafe', 'customization' => ['decorations' => false], 'version' => 1])->assertOk();
        $this->actingAs($this->bob)->putJson('/api/v1/couple/theme', ['theme_key' => 'midnight', 'customization' => [], 'version' => 2])->assertForbidden();
        $this->actingAs($this->bob)->putJson('/api/v1/couple/theme', ['theme_key' => 'sakura', 'customization' => [], 'version' => 2])->assertOk();
    }

    public function test_plan_changes_never_alter_existing_subscriptions(): void
    {
        $this->buy($this->alice);
        $subscription = $this->liveSubscription($this->couple);
        $boughtVersion = $subscription->planVersion;

        $admin = User::factory()->create(['is_admin' => true, 'admin_permissions' => ['plans.manage']]);
        $plans = app(PlanManagement::class);
        $love = SubscriptionPlan::where('key', 'love')->first();
        $draft = $plans->createDraft($love, $admin, [
            'price_amount' => 39_000,
            'entitlements' => ['storage_limit_bytes' => 50 * 1024 ** 3, 'premium_themes' => false, 'premium_photo_booth' => true],
        ]);
        $plans->publish($draft, $admin);

        // Existing subscriber: same version, same frozen benefits.
        $this->assertSame($boughtVersion->id, $subscription->refresh()->subscription_plan_version_id);
        $this->assertSame('archived', $boughtVersion->refresh()->status);
        $this->assertSame(29_000, $boughtVersion->price_amount);
        $granted = app(EntitlementService::class)->forCouple($this->couple);
        $this->assertSame([20 * 1024 ** 3, true, false], [$granted->storageLimitBytes(), $granted->allows('premium_themes'), $granted->allows('premium_photo_booth')]);

        // New buyers see the new version.
        $plan = collect($this->actingAs($this->alice)->getJson('/api/v1/billing/plans')->json('data.plans'))->firstWhere('key', 'love');
        $this->assertSame([2, 39_000], [$plan['version'], $plan['price_amount']]);

        // Published versions cannot be edited in place.
        $this->expectException(\LogicException::class);
        $boughtVersion->forceFill(['price_amount' => 1])->save();
    }

    public function test_paid_snapshot_never_gives_less_than_free(): void
    {
        $this->buy($this->alice);
        $admin = User::factory()->create(['is_admin' => true, 'admin_permissions' => ['plans.manage']]);
        $plans = app(PlanManagement::class);
        $free = SubscriptionPlan::free();
        $plans->publish($plans->createDraft($free, $admin, ['entitlements' => ['storage_limit_bytes' => 30 * 1024 ** 3]]), $admin);

        $this->assertSame(30 * 1024 ** 3, app(EntitlementService::class)->forCouple($this->couple)->storageLimitBytes());
    }
}
