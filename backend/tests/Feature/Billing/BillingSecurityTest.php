<?php

namespace Tests\Feature\Billing;

use App\Models\AdminAuditLog;
use App\Models\Couple;
use App\Models\CoupleSubscription;
use App\Models\PaymentWebhookEvent;
use App\Models\SubscriptionEvent;
use App\Models\User;
use App\Services\Billing\AdminSubscriptionActions;
use App\Services\Billing\EntitlementService;
use App\Services\Billing\Providers\MockPaymentProvider;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BillingSecurityTest extends TestCase
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

    public function test_webhook_with_bad_signature_is_rejected_and_not_stored(): void
    {
        $this->buy($this->alice);
        $token = $this->liveSubscription($this->couple)->provider_subscription_id;
        $hook = $this->store()->webhook($token, 'refund');

        $this->call('POST', '/api/v1/billing/webhooks/mock', server: [
            'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json',
            'HTTP_X_MOCK_SIGNATURE' => hash_hmac('sha256', $hook['body'], 'wrong-secret'),
        ], content: $hook['body'])->assertUnauthorized();

        // Tampered body with the original signature.
        $this->call('POST', '/api/v1/billing/webhooks/mock', server: [
            'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json',
            'HTTP_X_MOCK_SIGNATURE' => $hook['signature'],
        ], content: str_replace('refund', 'renew', $hook['body']))->assertUnauthorized();

        // Unconfigured real stores never accept anything.
        $this->postJson('/api/v1/billing/webhooks/google_play', ['message' => []])->assertUnauthorized();
        $this->postJson('/api/v1/billing/webhooks/stripe', [])->assertNotFound();

        $this->assertSame(0, PaymentWebhookEvent::count());
        $this->assertSame('active', $this->liveSubscription($this->couple)->status);
    }

    public function test_a_purchase_cannot_be_moved_to_another_couple(): void
    {
        [$carol, , $otherCouple] = $this->makeCouple();

        // Bought for Alice's couple, presented by Carol: the store's account token says otherwise.
        $token = $this->store()->purchase('love_monthly', $this->couple->billingAccountToken())['token'];
        $this->actingAs($carol)->postJson('/api/v1/couple/subscription/verify', [
            'provider' => 'mock', 'product_id' => 'love_monthly', 'purchase_token' => $token,
        ])->assertStatus(422)->assertJsonPath('data.code', 'account_mismatch');

        // Once linked to Alice's couple, restoring it elsewhere is refused too.
        $this->actingAs($this->alice)->postJson('/api/v1/couple/subscription/verify', [
            'provider' => 'mock', 'product_id' => 'love_monthly', 'purchase_token' => $token,
        ])->assertOk();
        $this->actingAs($carol)->postJson('/api/v1/couple/subscription/restore', [
            'provider' => 'mock', 'purchases' => [['product_id' => 'love_monthly', 'purchase_token' => $token]],
        ])->assertOk()->assertJsonPath('data.results.0.result', 'belongs_to_another_couple')->assertJsonPath('data.plan_key', 'free');

        $this->assertSame(1, CoupleSubscription::count());
        $this->assertSame($this->couple->id, CoupleSubscription::first()->couple_id);
        $this->assertFalse(app(EntitlementService::class)->forCouple($otherCouple)->allows('premium_themes'));
    }

    public function test_restore_relinks_the_couples_own_purchase(): void
    {
        $token = $this->store()->purchase('love_monthly', $this->couple->billingAccountToken())['token'];

        $this->actingAs($this->bob)->postJson('/api/v1/couple/subscription/restore', [
            'provider' => 'mock', 'purchases' => [['product_id' => 'love_monthly', 'purchase_token' => $token]],
        ])->assertOk()->assertJsonPath('data.results.0.result', 'restored')->assertJsonPath('data.plan_key', 'love');
    }

    public function test_only_the_purchaser_can_cancel(): void
    {
        $this->buy($this->alice);

        $this->actingAs($this->bob)->postJson('/api/v1/couple/subscription/cancel')
            ->assertForbidden()->assertJsonPath('data.code', 'not_purchaser');
        $this->assertSame('active', $this->liveSubscription($this->couple)->status);

        [$mallory] = $this->makeCouple();
        $this->actingAs($mallory)->postJson('/api/v1/couple/subscription/cancel')->assertNotFound()->assertJsonPath('data.code', 'no_subscription');
        $this->assertSame('active', $this->liveSubscription($this->couple)->status);
    }

    public function test_responses_never_expose_tokens_or_other_couples_transactions(): void
    {
        $this->buy($this->alice);
        $subscription = $this->liveSubscription($this->couple);
        $storeTxn = $subscription->transactions()->value('provider_transaction_id');
        [$carol] = $this->makeCouple();

        foreach (['/api/v1/couple/subscription', '/api/v1/couple/subscription/transactions', '/api/v1/billing/plans'] as $url) {
            $body = $this->actingAs($this->bob)->getJson($url)->assertOk()->getContent();
            $this->assertStringNotContainsString($subscription->provider_subscription_id, $body);
            $this->assertStringNotContainsString($storeTxn, $body);
            $this->assertStringNotContainsString($this->couple->billingAccountToken(), $body);
        }

        $this->actingAs($this->bob)->getJson('/api/v1/couple/subscription/transactions')->assertJsonCount(1, 'data.transactions');
        $this->actingAs($carol)->getJson('/api/v1/couple/subscription/transactions')->assertJsonCount(0, 'data.transactions');
        $this->actingAs($this->bob)->getJson('/api/v1/couple/subscription')->assertJsonPath('data.subscription.management_url', null);
    }

    public function test_mock_store_is_never_enabled_in_production(): void
    {
        $this->assertTrue(app(MockPaymentProvider::class)->isEnabled());

        $this->app->detectEnvironment(fn () => 'production');

        $this->assertFalse(app(MockPaymentProvider::class)->isEnabled());
    }

    public function test_admin_billing_screens_need_explicit_permissions(): void
    {
        $this->buy($this->alice);
        $subscription = $this->liveSubscription($this->couple);
        $plainAdmin = User::factory()->create(['is_admin' => true]);
        $viewer = User::factory()->create(['is_admin' => true, 'admin_permissions' => ['billing.view']]);
        $planner = User::factory()->create(['is_admin' => true, 'admin_permissions' => ['plans.manage']]);

        $billingPages = ['/admin/couple-subscriptions', "/admin/couple-subscriptions/{$subscription->id}", '/admin/payment-webhook-events'];
        $planPages = ['/admin/subscription-plans', '/admin/entitlement-definitions'];

        foreach ([...$billingPages, ...$planPages] as $url) {
            $this->actingAs($this->alice)->get($url)->assertForbidden();
            $this->actingAs($plainAdmin)->get($url)->assertForbidden();
        }
        foreach ($billingPages as $url) {
            $html = $this->actingAs($viewer)->get($url)->assertOk()->getContent();
            $this->assertStringNotContainsString($subscription->provider_subscription_id, $html);
            $this->assertStringNotContainsString($this->alice->email, $html);
        }
        foreach ($planPages as $url) {
            $this->actingAs($viewer)->get($url)->assertForbidden();
            $this->actingAs($planner)->get($url)->assertOk();
        }
    }

    public function test_manual_adjustments_need_billing_manage_and_are_audited(): void
    {
        $this->buy($this->alice);
        $subscription = $this->liveSubscription($this->couple);
        $actions = app(AdminSubscriptionActions::class);
        $viewer = User::factory()->create(['is_admin' => true, 'admin_permissions' => ['billing.view']]);
        $manager = User::factory()->create(['is_admin' => true, 'admin_permissions' => ['billing.view', 'billing.manage']]);

        try {
            $actions->suspend($subscription, $viewer, 'Chargeback under review');
            $this->fail('billing.view alone must not allow changes');
        } catch (AuthorizationException) {
        }

        try {
            $actions->suspend($subscription, $manager, '');
            $this->fail('a reason is required');
        } catch (\RuntimeException) {
        }

        $actions->suspend($subscription, $manager, 'Chargeback under review');
        $this->assertSame('suspended', $subscription->refresh()->status);
        $this->assertFalse(app(EntitlementService::class)->forCouple($this->couple)->allows('premium_themes'));

        // A store renewal does not silently lift an admin suspension.
        $this->store()->renew($subscription->provider_subscription_id);
        $this->webhook($subscription->provider_subscription_id, 'renewed');
        $this->assertSame('suspended', $subscription->refresh()->status);

        $actions->reinstate($subscription, $manager, 'Chargeback resolved in our favour');
        $this->assertSame('active', $subscription->refresh()->status);

        $event = SubscriptionEvent::where('type', 'status_changed')->where('to_status', 'suspended')->first();
        $this->assertSame(["admin:{$manager->id}", 'Chargeback under review'], [$event->actor, $event->reason]);
        $this->expectException(\LogicException::class);
        $event->forceFill(['reason' => 'edited'])->save();
    }

    public function test_manual_grant_expires_on_its_own(): void
    {
        $manager = User::factory()->create(['is_admin' => true, 'admin_permissions' => ['billing.manage']]);
        app(AdminSubscriptionActions::class)->grant($this->couple, \App\Models\SubscriptionPlan::where('key', 'together_plus')->first(), 7, $manager, 'Compensation for outage');

        $this->actingAs($this->bob)->getJson('/api/v1/couple/subscription')
            ->assertJsonPath('data.plan_key', 'together_plus')
            ->assertJsonPath('data.subscription.started_by', 'support')
            ->assertJsonPath('data.subscription.can_manage', false);

        $this->travel(8)->days();
        $this->artisan('billing:sweep')->assertSuccessful();
        $this->assertSame('expired', CoupleSubscription::first()->status);
        $this->actingAs($this->bob)->getJson('/api/v1/couple/subscription')->assertJsonPath('data.plan_key', 'free');
    }

    public function test_permissions_are_granted_only_from_the_cli_and_audited(): void
    {
        $admin = User::factory()->create(['is_admin' => true, 'email' => 'ops@example.test']);
        $user = User::factory()->create(['email' => 'user@example.test']);

        $this->artisan('admin:permission', ['action' => 'grant', 'email' => 'ops@example.test', 'permission' => 'billing.view'])->assertSuccessful();
        $this->artisan('admin:permission', ['action' => 'grant', 'email' => 'user@example.test', 'permission' => 'billing.view'])->assertFailed();
        $this->artisan('admin:permission', ['action' => 'grant', 'email' => 'ops@example.test', 'permission' => 'everything'])->assertFailed();

        $this->assertTrue($admin->refresh()->hasAdminPermission('billing.view'));
        $this->assertFalse($user->refresh()->hasAdminPermission('billing.view'));
        $this->assertSame(1, AdminAuditLog::where('action', 'permission_grant')->count());

        // Not mass-assignable through user forms.
        $admin->update(['admin_permissions' => ['billing.manage']]);
        $this->assertSame(['billing.view'], $admin->refresh()->admin_permissions);
    }
}
