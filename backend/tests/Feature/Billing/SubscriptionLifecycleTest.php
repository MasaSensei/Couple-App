<?php

namespace Tests\Feature\Billing;

use App\Models\Couple;
use App\Models\CoupleSubscription;
use App\Models\PaymentWebhookEvent;
use App\Models\SubscriptionEvent;
use App\Models\SubscriptionTransaction;
use App\Models\User;
use App\Services\Billing\EntitlementService;
use App\Services\Billing\SubscriptionService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SubscriptionLifecycleTest extends TestCase
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
    }

    private function entitlements(): \App\Services\Billing\Entitlements
    {
        return app(EntitlementService::class)->forCouple($this->couple);
    }

    public function test_a_new_couple_is_on_the_free_plan(): void
    {
        $this->actingAs($this->alice)->getJson('/api/v1/couple/subscription')
            ->assertOk()
            ->assertJsonPath('data.plan_key', 'free')
            ->assertJsonPath('data.subscription', null)
            ->assertJsonPath('data.entitlements.premium_themes', false)
            ->assertJsonPath('data.storage.limit_bytes', 1024 ** 3);
    }

    public function test_plans_list_offered_plans_with_price_interval_and_features(): void
    {
        $plans = $this->actingAs($this->alice)->getJson('/api/v1/billing/plans')->assertOk()->json('data.plans');

        $this->assertSame(['free', 'love', 'together_plus'], array_column($plans, 'key'));
        $this->assertTrue($plans[0]['is_current']);
        $this->assertSame([29000, 'IDR', 'month', true], [$plans[1]['price_amount'], $plans[1]['currency'], $plans[1]['billing_interval'], $plans[1]['auto_renews']]);
        $this->assertSame(['storage_limit_bytes', 'premium_themes', 'premium_photo_booth'], array_column($plans[1]['features'], 'key'));
        $this->assertSame(['mock' => 'love_monthly'], $plans[1]['products']); // only enabled providers
    }

    public function test_verified_purchase_activates_the_plan_for_both_partners(): void
    {
        $this->buy($this->alice)->assertOk()
            ->assertJsonPath('data.plan_key', 'love')
            ->assertJsonPath('data.subscription.status', 'active')
            ->assertJsonPath('data.subscription.started_by', 'me')
            ->assertJsonPath('data.subscription.can_manage', true);

        // Bob paid nothing and gets the same benefits; he sees but cannot manage.
        $this->actingAs($this->bob)->getJson('/api/v1/couple/subscription')
            ->assertJsonPath('data.plan_key', 'love')
            ->assertJsonPath('data.entitlements.premium_themes', true)
            ->assertJsonPath('data.storage.limit_bytes', 20 * 1024 ** 3)
            ->assertJsonPath('data.subscription.started_by', 'partner')
            ->assertJsonPath('data.subscription.can_manage', false);

        $this->assertSame(1, SubscriptionTransaction::where('couple_id', $this->couple->id)->where('type', 'purchase')->count());
        $this->assertTrue(SubscriptionEvent::where('type', 'created')->where('actor', "user:{$this->alice->id}")->exists());
    }

    public function test_couple_cannot_hold_two_subscriptions(): void
    {
        $this->buy($this->alice)->assertOk();

        $this->actingAs($this->bob)->postJson('/api/v1/couple/subscription/intents', ['plan_key' => 'love', 'provider' => 'mock'])
            ->assertStatus(409)->assertJsonPath('data.code', 'already_subscribed');

        // Even if a second purchase reaches the store, it is never stacked.
        $token = $this->store()->purchase('together_plus_monthly', $this->couple->billingAccountToken())['token'];
        $this->actingAs($this->bob)->postJson('/api/v1/couple/subscription/verify', [
            'provider' => 'mock', 'product_id' => 'together_plus_monthly', 'purchase_token' => $token,
        ])->assertStatus(409)->assertJsonPath('data.code', 'duplicate_subscription');

        $this->assertSame(1, CoupleSubscription::where('couple_id', $this->couple->id)->count());
        $this->assertTrue(SubscriptionEvent::where('type', 'duplicate_subscription')->exists());
    }

    public function test_renewal_extends_the_period_and_records_one_transaction(): void
    {
        $this->buy($this->alice);
        $subscription = $this->liveSubscription($this->couple);
        $firstEnd = $subscription->current_period_end;

        $this->travelTo($firstEnd->copy()->subHour());
        $this->store()->renew($subscription->provider_subscription_id);
        $this->webhook($subscription->provider_subscription_id, 'renewed')->assertOk();

        $subscription->refresh();
        $this->assertSame('active', $subscription->status);
        $this->assertTrue($subscription->current_period_end->gt($firstEnd));
        $this->assertSame(['purchase', 'renewal'], SubscriptionTransaction::orderBy('id')->pluck('type')->all());
    }

    public function test_cancel_keeps_benefits_until_period_end_then_expires_without_deleting_data(): void
    {
        $this->buy($this->alice);
        $photo = $this->photo($this->couple, $this->alice, 5 * 1024 ** 3);
        $end = $this->liveSubscription($this->couple)->current_period_end;

        $this->travelTo($end->copy()->subDays(20)); // "cancelled on the 10th"
        $this->actingAs($this->alice)->postJson('/api/v1/couple/subscription/cancel')
            ->assertOk()
            ->assertJsonPath('data.subscription.status', 'cancelled')
            ->assertJsonPath('data.subscription.auto_renew', false)
            ->assertJsonPath('data.subscription.renews_at', null)
            ->assertJsonPath('data.subscription.benefits_end_at', $end->toISOString());

        $this->assertTrue($this->entitlements()->allows('premium_themes'), 'still entitled before period end');

        $this->travelTo($end->copy()->addSecond());
        $this->assertFalse($this->entitlements()->allows('premium_themes'), 'benefits stop exactly at period end, even before the sweep');

        app(SubscriptionService::class)->sweep();
        $subscription = CoupleSubscription::first();
        $this->assertSame(['expired', 'expired'], [$subscription->status, $subscription->ended_reason]);
        $this->assertNotNull(\App\Models\MemoryPhoto::find($photo->id), 'expiry never deletes photos');
        $this->actingAs($this->alice)->getJson('/api/v1/couple/subscription')->assertJsonPath('data.plan_key', 'free');
    }

    public function test_failed_renewal_enters_grace_then_payment_failed_then_recovers(): void
    {
        $this->buy($this->alice);
        $subscription = $this->liveSubscription($this->couple);
        $token = $subscription->provider_subscription_id;

        $this->travelTo($subscription->current_period_end->copy()->addMinute());
        $this->store()->failRenewal($token);
        $this->webhook($token, 'renewal_failed');

        $subscription->refresh();
        $this->assertSame('grace_period', $subscription->status);
        $this->assertTrue($this->entitlements()->allows('premium_themes'), 'grace keeps benefits');

        $this->travelTo($subscription->grace_ends_at->copy()->addMinute());
        $this->store()->hold($token);
        $this->webhook($token, 'on_hold');
        $this->assertSame('payment_failed', $subscription->refresh()->status);
        $this->assertFalse($this->entitlements()->allows('premium_themes'));

        $this->store()->renew($token); // user fixed the card in the store
        $this->webhook($token, 'recovered');
        $this->assertSame('active', $subscription->refresh()->status);
        $this->assertTrue($this->entitlements()->allows('premium_themes'));
    }

    public function test_refund_and_chargeback_end_benefits_immediately(): void
    {
        foreach (['refund' => 'refunded', 'chargeback' => 'chargeback'] as $kind => $reason) {
            CoupleSubscription::query()->update(['status' => 'expired']);
            $this->buy($this->alice)->assertOk();
            $token = $this->liveSubscription($this->couple)->provider_subscription_id;

            $this->store()->refund($token, chargeback: $kind === 'chargeback');
            $this->webhook($token, $kind)->assertOk();

            $subscription = CoupleSubscription::where('provider_subscription_id', $token)->first();
            $this->assertSame(['expired', $reason], [$subscription->status, $subscription->ended_reason]);
            $this->assertFalse($this->entitlements()->allows('premium_themes'));
            $this->assertSame(-29000, SubscriptionTransaction::where('provider_transaction_id', $subscription->transactions()->where('type', 'purchase')->value('provider_transaction_id'))->where('type', $kind)->value('amount'));
        }
    }

    public function test_duplicate_webhook_is_applied_once(): void
    {
        $this->buy($this->alice);
        $token = $this->liveSubscription($this->couple)->provider_subscription_id;
        $this->store()->renew($token);

        $this->webhook($token, 'renewed', 'evt_same')->assertOk()->assertJsonPath('data.status', 'accepted');
        $this->webhook($token, 'renewed', 'evt_same')->assertOk()->assertJsonPath('data.status', 'duplicate');

        $this->assertSame(1, PaymentWebhookEvent::count());
        $this->assertSame(1, SubscriptionTransaction::where('type', 'renewal')->count());
    }

    public function test_delayed_out_of_order_state_never_rolls_back(): void
    {
        $this->buy($this->alice);
        $subscription = $this->liveSubscription($this->couple);
        $token = $subscription->provider_subscription_id;
        $staleState = app(\App\Services\Billing\Providers\MockPaymentProvider::class)->fetchSubscription($token); // "active"

        $this->store()->refund($token);
        $this->webhook($token, 'refund');
        $this->assertSame('expired', $subscription->refresh()->status);

        // An old "active" state arriving late is ignored.
        app(SubscriptionService::class)->applyProviderState($staleState, 'provider:mock');
        $this->assertSame('expired', $subscription->refresh()->status);
        $this->assertFalse($this->entitlements()->allows('premium_themes'));
    }

    public function test_provider_outage_never_punishes_the_couple(): void
    {
        $this->buy($this->alice);
        $subscription = $this->liveSubscription($this->couple);
        $this->store()->setOutage(true);

        // Webhook stored but not applicable while the store API is down; retried later.
        $this->store()->renew($subscription->provider_subscription_id);
        $this->webhook($subscription->provider_subscription_id, 'renewed')->assertOk();
        $this->assertSame('failed', PaymentWebhookEvent::first()->status);

        // Renewal unconfirmed past the leeway: grace instead of losing benefits.
        $this->travelTo($subscription->current_period_end->copy()->addHours(config('billing.renewal_leeway_hours') + 1));
        app(SubscriptionService::class)->sweep();
        $this->assertSame('grace_period', $subscription->refresh()->status);
        $this->assertTrue($this->entitlements()->allows('premium_themes'));

        // Store back: the retry applies the real (renewed) state.
        $this->store()->setOutage(false);
        $this->travel(11)->minutes();
        $this->artisan('billing:retry-webhooks')->assertSuccessful();
        $this->assertSame('processed', PaymentWebhookEvent::first()->status);
        $this->assertSame('active', $subscription->refresh()->status);
    }

    public function test_plan_change_by_purchaser_replaces_the_old_subscription(): void
    {
        $this->buy($this->alice);
        $old = $this->liveSubscription($this->couple);

        $this->actingAs($this->bob)->postJson('/api/v1/couple/subscription/intents', ['plan_key' => 'together_plus', 'provider' => 'mock'])
            ->assertStatus(403)->assertJsonPath('data.code', 'not_purchaser');

        $this->buy($this->alice, 'together_plus')->assertOk()->assertJsonPath('data.plan_key', 'together_plus');

        $this->assertSame(['expired', 'replaced'], [$old->refresh()->status, $old->ended_reason]);
        $this->assertTrue($this->entitlements()->allows('premium_photo_booth'));
    }

    public function test_status_transitions_are_validated(): void
    {
        $lifecycle = app(\App\Services\Billing\SubscriptionLifecycle::class);

        $this->assertFalse($lifecycle->canTransition('expired', 'active', 'user:1'));
        $this->assertFalse($lifecycle->canTransition('expired', 'active', 'admin:1'));
        $this->assertTrue($lifecycle->canTransition('expired', 'active', 'provider:app_store'));
        $this->assertFalse($lifecycle->canTransition('cancelled', 'grace_period', 'system'));
        $this->assertFalse($lifecycle->canTransition('payment_failed', 'suspended', 'system'));

        $this->buy($this->alice);
        $subscription = $this->liveSubscription($this->couple);
        $lifecycle->transition($subscription, 'expired', 'system');

        $this->expectException(\LogicException::class);
        $lifecycle->transition($subscription, 'active', 'admin:1');
    }
}
