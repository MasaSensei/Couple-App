<?php

namespace App\Services\Billing;

use App\Models\Couple;
use App\Models\CoupleSubscription;
use App\Models\SubscriptionEvent;
use App\Models\SubscriptionPlan;
use App\Models\SubscriptionPlanVersion;
use App\Models\SubscriptionPurchaseIntent;
use App\Models\SubscriptionTransaction;
use App\Models\User;
use App\Services\Billing\Providers\PaymentProvider;
use App\Services\Billing\Providers\PaymentProviderRegistry;
use App\Services\Billing\Providers\PaymentProviderUnavailable;
use App\Services\Billing\Providers\ProviderSubscriptionState;
use App\Services\Billing\Providers\PurchaseVerificationFailed;
use Illuminate\Support\Facades\DB;

/**
 * Couple subscriptions: purchase, verification, restore, cancellation and
 * reconciliation with the providers. See docs/billing/subscriptions.md.
 *
 * Ownership rules (§5):
 *  - The subscription belongs to the Couple. Both partners get the same
 *    entitlements and both can see its status and history.
 *  - Either partner may start a subscription when the couple has none.
 *  - Only the purchaser can change plan or cancel renewal: store
 *    subscriptions are billed to *their* store account, and the partner
 *    must never be able to touch someone else's payment.
 *  - A purchase is bound to the couple through `billing_account_token`
 *    (given to the store at purchase) and (provider, subscription id) is
 *    unique, so a token can never be attached to — or follow a member
 *    into — another couple.
 *
 * Trust rule: status, dates and amounts only ever come from
 * ProviderSubscriptionState, i.e. from the provider's server. The app
 * only sends an opaque token.
 */
class SubscriptionService
{
    public function __construct(
        private readonly PaymentProviderRegistry $providers,
        private readonly SubscriptionLifecycle $lifecycle,
        private readonly EntitlementCatalog $catalog,
    ) {}

    public function liveSubscription(Couple $couple): ?CoupleSubscription
    {
        return CoupleSubscription::where('couple_id', $couple->id)->live()->with('planVersion.plan')->first();
    }

    /**
     * Step 1 of a purchase: checks the couple may buy this plan and returns
     * what the app passes to the store (product id + account token).
     */
    public function createIntent(User $user, Couple $couple, SubscriptionPlan $plan, string $providerKey): array
    {
        $provider = $this->enabledProvider($providerKey);
        $version = $plan->publishedVersion;

        if ($plan->is_free || $plan->status !== 'active' || $version === null) {
            throw new BillingException('plan_unavailable', 'This plan is not available for purchase.');
        }

        $productId = $version->productIdFor($provider->key())
            ?? throw new BillingException('plan_unavailable', 'This plan cannot be bought on this platform.');

        $replaces = null;
        $live = $this->liveSubscription($couple);

        if ($live !== null) {
            if (in_array($live->status, ['pending', 'payment_failed', 'suspended'], true)) {
                throw new BillingException('subscription_needs_attention', 'Your current subscription needs attention first. Check its status in Subscription settings.', 409);
            }
            if ($live->planVersion->subscription_plan_id === $plan->id) {
                throw new BillingException('already_subscribed', 'Your couple space already has this plan.', 409);
            }
            if ($live->purchased_by !== $user->id) {
                throw new BillingException('not_purchaser', 'Only the partner who started the subscription can change the plan, because it is billed to their store account.', 403);
            }
            if ($live->provider !== $provider->key()) {
                throw new BillingException('different_provider', 'Your subscription is billed through another store. Change plans there.', 409);
            }
            $replaces = $live->provider_subscription_id;
        }

        $intent = SubscriptionPurchaseIntent::forceCreate([
            'couple_id' => $couple->id,
            'user_id' => $user->id,
            'subscription_plan_version_id' => $version->id,
            'provider' => $provider->key(),
            'product_id' => $productId,
            'expires_at' => now()->addMinutes(config('billing.purchase_intent_ttl_minutes')),
        ]);

        return [
            'intent_id' => $intent->id,
            'provider' => $provider->key(),
            'product_id' => $productId,
            'account_token' => $couple->billingAccountToken(),
            'replaces_subscription_id' => $replaces,
            'expires_at' => $intent->expires_at->toISOString(),
        ];
    }

    /** Step 2: the app hands over the store's token; the provider's server decides. */
    public function verifyPurchase(User $user, Couple $couple, string $providerKey, string $productId, string $token): CoupleSubscription
    {
        $provider = $this->enabledProvider($providerKey);

        try {
            $state = $provider->verifyPurchase($productId, $token);
        } catch (PurchaseVerificationFailed $exception) {
            SubscriptionEvent::record($couple, null, 'purchase_rejected', "user:{$user->id}", [
                'reason' => $exception->getMessage(),
                'data' => ['provider' => $providerKey, 'product_id' => $productId],
            ]);

            throw new BillingException('purchase_invalid', 'The store could not confirm this purchase.', 422);
        }

        $intent = SubscriptionPurchaseIntent::query()
            ->where('couple_id', $couple->id)
            ->where('provider', $provider->key())
            ->where('product_id', $state->productId)
            ->whereNull('consumed_at')
            ->where('expires_at', '>', now())
            ->latest('id')
            ->first();

        $subscription = $this->applyProviderState($state, "user:{$user->id}", $couple, $user, $intent?->planVersion);

        $intent?->forceFill(['consumed_at' => now()])->save();

        return $subscription;
    }

    /**
     * Re-links store purchases after a reinstall / new phone. Each token is
     * verified like a new purchase; one that belongs to another couple is
     * reported, never transferred.
     *
     * @param  list<array{product_id: string, purchase_token: string}>  $purchases
     */
    public function restore(User $user, Couple $couple, string $providerKey, array $purchases): array
    {
        $results = [];

        foreach ($purchases as $purchase) {
            try {
                $subscription = $this->verifyPurchase($user, $couple, $providerKey, $purchase['product_id'], $purchase['purchase_token']);
                $results[] = ['product_id' => $purchase['product_id'], 'result' => 'restored', 'status' => $subscription->status];
            } catch (BillingException $exception) {
                $results[] = ['product_id' => $purchase['product_id'], 'result' => $exception->errorCode];
            }
        }

        return $results;
    }

    /**
     * Turns off auto-renew. Benefits continue until the paid period ends;
     * nothing is deleted. Store subscriptions that can only be cancelled in
     * the store return the store's management link instead (409).
     */
    public function cancelRenewal(User $user, Couple $couple): CoupleSubscription
    {
        $live = $this->liveSubscription($couple)
            ?? throw new BillingException('no_subscription', 'Your couple space has no paid subscription.', 404);

        if ($live->provider === 'manual') {
            throw new BillingException('managed_by_support', 'This plan was granted by support and does not renew.', 409);
        }

        if ($live->purchased_by !== $user->id) {
            throw new BillingException('not_purchaser', 'Only the partner who started the subscription can cancel it, because it is billed to their store account.', 403);
        }

        if ($live->status === 'cancelled') {
            return $live;
        }

        if (! in_array($live->status, ['active', 'grace_period', 'payment_failed'], true)) {
            throw new BillingException('not_cancellable', 'This subscription cannot be cancelled right now.', 409);
        }

        $provider = $this->providers->get($live->provider)
            ?? throw new BillingException('provider_unavailable', 'This store is not available.', 503);

        try {
            $state = $provider->cancelRenewal($live);
        } catch (PaymentProviderUnavailable) {
            throw new BillingException('provider_unavailable', 'The store is not reachable right now. Please try again later.', 503);
        }

        if ($state === null) {
            throw new BillingException('manage_in_store', 'Cancel this subscription in your store’s subscription settings.', 409, [
                'management_url' => $provider->managementUrl($live),
            ]);
        }

        SubscriptionEvent::record($couple, $live, 'cancel_requested', "user:{$user->id}");

        return $this->applyProviderState($state, "user:{$user->id}", $couple);
    }

    /**
     * Brings our record in line with the provider's authoritative state.
     * Idempotent, and ignores states older than the one already applied, so
     * duplicate or out-of-order webhooks are harmless.
     *
     * @throws BillingException|UnknownSubscription
     */
    public function applyProviderState(
        ProviderSubscriptionState $state,
        string $actor,
        ?Couple $couple = null,
        ?User $purchaser = null,
        ?SubscriptionPlanVersion $version = null,
    ): CoupleSubscription {
        try {
            return DB::transaction(fn () => $this->applyLocked($state, $actor, $couple, $purchaser, $version));
        } catch (BillingException $exception) {
            // Audit outside the rolled-back transaction.
            if (isset($exception->data['couple_id'])) {
                SubscriptionEvent::record($exception->data['couple_id'], null, $exception->errorCode, $actor, [
                    'reason' => $exception->getMessage(),
                    'data' => ['provider' => $state->provider, 'product_id' => $state->productId],
                ]);
            }

            throw $exception;
        }
    }

    private function applyLocked(ProviderSubscriptionState $state, string $actor, ?Couple $couple, ?User $purchaser, ?SubscriptionPlanVersion $version): CoupleSubscription
    {
        $subscription = CoupleSubscription::query()
            ->where('provider', $state->provider)
            ->where('provider_subscription_id', $state->subscriptionId)
            ->lockForUpdate()
            ->first();

        if ($subscription !== null && $couple !== null && $subscription->couple_id !== $couple->id) {
            throw new BillingException('belongs_to_another_couple', 'This purchase belongs to another couple space and cannot be moved.', 409, ['couple_id' => $couple->id]);
        }

        if ($subscription === null) {
            $subscription = $this->createFromState($state, $actor, $couple, $purchaser, $version);
        } elseif ($subscription->provider_state_at !== null && $state->stateAt->lt($subscription->provider_state_at)) {
            // Stale (delayed / out-of-order): keep the newer state we already have.
            $subscription->forceFill(['last_synced_at' => now()])->save();
        } else {
            $this->updateFromState($subscription, $state, $actor);
        }

        $this->recordTransactions($subscription, $state, $actor);

        return $subscription->refresh()->load('planVersion.plan');
    }

    private function createFromState(ProviderSubscriptionState $state, string $actor, ?Couple $couple, ?User $purchaser, ?SubscriptionPlanVersion $version): CoupleSubscription
    {
        $couple ??= $state->accountToken ? Couple::where('billing_account_token', $state->accountToken)->first() : null;

        if ($couple === null) {
            throw new UnknownSubscription("No couple for {$state->provider} subscription.");
        }

        // The store records which couple the purchase was made for.
        if ($state->accountToken === null || ! hash_equals($couple->billingAccountToken(), $state->accountToken)) {
            throw new BillingException('account_mismatch', 'This purchase was made for a different couple space.', 422, ['couple_id' => $couple->id]);
        }

        Couple::whereKey($couple->id)->lockForUpdate()->first();

        $version ??= $this->versionForProduct($state->provider, $state->productId);

        if ($version->productIdFor($state->provider) !== $state->productId) {
            $version = $this->versionForProduct($state->provider, $state->productId);
        }

        // Plan change: the store replaced the old subscription with this one.
        if ($state->replacesSubscriptionId !== null) {
            $old = CoupleSubscription::query()
                ->where('couple_id', $couple->id)
                ->where('provider', $state->provider)
                ->where('provider_subscription_id', $state->replacesSubscriptionId)
                ->lockForUpdate()
                ->first();

            if ($old !== null && $old->status !== 'expired') {
                $this->lifecycle->transition($old, 'expired', $actor, 'Replaced by a plan change.', ['ended_reason' => 'replaced']);
            }
        }

        $status = $state->status();

        if (in_array($status, CoupleSubscription::LIVE, true)
            && CoupleSubscription::where('couple_id', $couple->id)->live()->exists()) {
            throw new BillingException('duplicate_subscription',
                'Your couple space already has a subscription, so this purchase was not applied. Cancel and request a refund for the extra purchase in the store.',
                409, ['couple_id' => $couple->id]);
        }

        $subscription = new CoupleSubscription;
        $subscription->forceFill([
            'couple_id' => $couple->id,
            'subscription_plan_version_id' => $version->id,
            'purchased_by' => $purchaser?->id,
            'provider' => $state->provider,
            'provider_subscription_id' => $state->subscriptionId,
            'status' => $status,
            'ended_reason' => $status === 'expired' ? $state->endedReason() : null,
            'ended_at' => $status === 'expired' ? now() : null,
            'auto_renew' => $state->autoRenew,
            'current_period_start' => $state->periodStart,
            'current_period_end' => $state->periodEnd,
            'grace_ends_at' => $status === 'grace_period' ? $state->graceEndsAt : null,
            'cancelled_at' => $status === 'cancelled' ? now() : null,
            'provider_state_at' => $state->stateAt,
            'last_synced_at' => now(),
            // Frozen copy: later edits to the plan never change what was bought.
            'entitlements_snapshot' => $this->catalog->validate($version->entitlements ?? []),
        ])->save();

        SubscriptionEvent::record($couple, $subscription, 'created', $actor, [
            'to' => $status,
            'data' => ['plan_version_id' => $version->id, 'provider' => $state->provider, 'test' => $state->isTest],
        ]);

        return $subscription;
    }

    private function updateFromState(CoupleSubscription $subscription, ProviderSubscriptionState $state, string $actor): void
    {
        $to = $state->status();

        // An admin suspension sticks until an admin lifts it; the provider can still end it.
        if ($subscription->admin_suspended && $to !== 'expired') {
            $to = 'suspended';
        }

        if (! $this->lifecycle->canTransition($subscription->status, $to, $actor)) {
            SubscriptionEvent::record($subscription->couple_id, $subscription, 'transition_ignored', $actor, [
                'from' => $subscription->status,
                'to' => $to,
                'reason' => 'Provider state not applicable to the current status.',
            ]);
            $subscription->forceFill(['last_synced_at' => now()])->save();

            return;
        }

        $attributes = [
            'auto_renew' => $state->autoRenew,
            'current_period_start' => $state->periodStart,
            'current_period_end' => $state->periodEnd,
            'grace_ends_at' => $to === 'grace_period' ? $state->graceEndsAt : null,
            'provider_state_at' => $state->stateAt,
            'last_synced_at' => now(),
        ];

        if ($to === 'expired') {
            $attributes['ended_reason'] = $subscription->status === 'expired' ? $subscription->ended_reason : $state->endedReason();
        }

        $this->lifecycle->transition($subscription, $to, $actor, null, $attributes);
    }

    private function recordTransactions(CoupleSubscription $subscription, ProviderSubscriptionState $state, string $actor): void
    {
        foreach ($state->transactions as $transaction) {
            $key = [
                'provider' => $state->provider,
                'provider_transaction_id' => $transaction['id'],
                'type' => $transaction['type'],
            ];

            if (SubscriptionTransaction::where($key)->exists()) {
                continue; // already recorded (duplicate / repeated sync)
            }

            $row = SubscriptionTransaction::forceCreate([
                ...$key,
                'couple_id' => $subscription->couple_id,
                'couple_subscription_id' => $subscription->id,
                'subscription_plan_version_id' => $subscription->subscription_plan_version_id,
                'amount' => $transaction['amount'],
                'currency' => $transaction['currency'],
                'occurred_at' => $transaction['occurred_at'],
                'metadata' => ['test' => $state->isTest],
            ]);

            SubscriptionEvent::record($subscription->couple_id, $subscription, "transaction_{$transaction['type']}", $actor, [
                'data' => ['transaction_id' => $row->id, 'amount' => $row->amount, 'currency' => $row->currency],
            ]);
        }
    }

    /**
     * Periodic safety net (scheduled hourly). Moves subscriptions whose time
     * is up, asking the provider first. If the provider is unreachable the
     * couple is never punished for our outage: cancelled ones still end on
     * time (that needs no provider), renewals get a grace period instead.
     *
     * @return array<string, int>
     */
    public function sweep(): array
    {
        $counts = ['synced' => 0, 'expired' => 0, 'grace' => 0, 'unavailable' => 0];

        $due = CoupleSubscription::query()
            ->live()
            ->where(fn ($query) => $query
                ->where('current_period_end', '<=', now())
                ->orWhere('grace_ends_at', '<=', now())
                ->orWhere(fn ($query) => $query->where('status', 'pending')->where('created_at', '<=', now()->subDay())))
            ->get();

        foreach ($due as $subscription) {
            $provider = $this->providers->get($subscription->provider);

            if ($provider !== null && $subscription->provider_subscription_id !== null) {
                try {
                    $this->applyProviderState($provider->fetchSubscription($subscription->provider_subscription_id), 'system', $subscription->couple);
                    $counts['synced']++;

                    continue;
                } catch (PaymentProviderUnavailable|PurchaseVerificationFailed) {
                    $counts['unavailable']++;
                }
            }

            $result = $this->sweepLocally($subscription->refresh());
            $counts[$result] = ($counts[$result] ?? 0) + 1;
        }

        return $counts;
    }

    /** Local fallback when the provider cannot be asked (or for `manual`). */
    private function sweepLocally(CoupleSubscription $subscription): string
    {
        $endedPeriod = $subscription->current_period_end?->isPast() ?? false;

        if (in_array($subscription->status, ['cancelled', 'pending'], true) && ($endedPeriod || $subscription->status === 'pending')
            || $subscription->status === 'active' && ! $subscription->auto_renew && $endedPeriod) {
            $this->lifecycle->transition($subscription, 'expired', 'system', 'Paid period ended.');

            return 'expired';
        }

        if ($subscription->status === 'active' && $endedPeriod
            && now()->gte($subscription->current_period_end->copy()->addHours(config('billing.renewal_leeway_hours')))) {
            $this->lifecycle->transition($subscription, 'grace_period', 'system', 'Renewal not confirmed by the store yet.', [
                'grace_ends_at' => $subscription->current_period_end->copy()->addDays(config('billing.default_grace_period_days')),
            ]);

            return 'grace';
        }

        if ($subscription->status === 'grace_period' && $subscription->grace_ends_at?->isPast()) {
            $this->lifecycle->transition($subscription, 'payment_failed', 'system', 'Grace period ended without a confirmed payment.');

            return 'payment_failed';
        }

        return 'unchanged';
    }

    private function enabledProvider(string $key): PaymentProvider
    {
        $provider = $this->providers->get($key);

        if ($provider === null || ! $provider->isEnabled()) {
            throw new BillingException('provider_unavailable', 'Purchases through this store are not available yet.', 422);
        }

        return $provider;
    }

    private function versionForProduct(string $provider, string $productId): SubscriptionPlanVersion
    {
        return SubscriptionPlanVersion::query()
            ->whereIn('status', ['published', 'archived'])
            ->where("provider_products->{$provider}", $productId)
            ->orderByRaw("status = 'published' DESC")
            ->orderByDesc('id')
            ->first()
            ?? throw new BillingException('purchase_invalid', 'This product is not one of our plans.', 422);
    }
}
