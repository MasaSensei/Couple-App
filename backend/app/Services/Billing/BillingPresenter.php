<?php

namespace App\Services\Billing;

use App\Models\Couple;
use App\Models\CoupleSubscription;
use App\Models\EntitlementDefinition;
use App\Models\SubscriptionPlan;
use App\Models\SubscriptionTransaction;
use App\Models\User;
use App\Services\Billing\Providers\PaymentProviderRegistry;

/**
 * API shapes for billing. Never includes purchase tokens, store transaction
 * ids, raw provider payloads or anything about another couple.
 */
class BillingPresenter
{
    public function __construct(
        private readonly PaymentProviderRegistry $providers,
        private readonly EntitlementService $entitlements,
        private readonly StorageQuotaService $quota,
    ) {}

    public function plan(SubscriptionPlan $plan, ?string $currentPlanKey = null): array
    {
        $version = $plan->publishedVersion;
        $definitions = EntitlementDefinition::orderBy('sort_order')->get();
        $enabled = $this->providers->enabledKeys();

        return [
            'key' => $plan->key,
            'name' => $plan->name,
            'description' => $plan->description,
            'is_free' => $plan->is_free,
            'is_current' => $currentPlanKey === $plan->key,
            'version' => $version->version,
            'price_amount' => $version->price_amount,
            'currency' => $version->currency,
            'billing_interval' => $version->billing_interval,
            'billing_interval_count' => $version->billing_interval_count,
            'auto_renews' => $version->isRecurring(),
            'storage_limit_bytes' => (int) ($version->entitlements['storage_limit_bytes'] ?? 0),
            'features' => $definitions->map(fn (EntitlementDefinition $definition) => [
                'key' => $definition->key,
                'name' => $definition->name,
                'description' => $definition->description,
                'type' => $definition->type,
                'value' => $version->entitlements[$definition->key] ?? $definition->default_value,
            ])->values(),
            'products' => (object) array_intersect_key($version->provider_products ?? [], array_flip($enabled)),
        ];
    }

    public function overview(Couple $couple, User $viewer, ?CoupleSubscription $live): array
    {
        $granted = $this->entitlements->forCouple($couple);

        return [
            'plan_key' => $granted->planKey,
            'subscription' => $live ? $this->subscription($live, $viewer) : null,
            'entitlements' => $granted->toArray(),
            'storage' => $this->quota->usage($couple),
            'available_providers' => $this->providers->enabledKeys(),
        ];
    }

    public function subscription(CoupleSubscription $subscription, User $viewer): array
    {
        $version = $subscription->planVersion;
        $isPurchaser = $subscription->purchased_by === $viewer->id;
        $provider = $this->providers->get($subscription->provider);

        return [
            'id' => $subscription->id,
            'status' => $subscription->status,
            'is_entitled' => $subscription->isEntitled(),
            'plan' => ['key' => $version->plan->key, 'name' => $version->plan->name],
            'price_amount' => $version->price_amount,
            'currency' => $version->currency,
            'billing_interval' => $version->billing_interval,
            'billing_interval_count' => $version->billing_interval_count,
            'provider' => $subscription->provider,
            'auto_renew' => $subscription->auto_renew,
            'current_period_start' => $subscription->current_period_start?->toISOString(),
            'current_period_end' => $subscription->current_period_end?->toISOString(),
            'renews_at' => $subscription->status === 'active' && $subscription->auto_renew ? $subscription->current_period_end?->toISOString() : null,
            'benefits_end_at' => match ($subscription->status) {
                'cancelled' => $subscription->current_period_end?->toISOString(),
                'active' => $subscription->auto_renew ? null : $subscription->current_period_end?->toISOString(),
                'grace_period' => $subscription->grace_ends_at?->toISOString(),
                default => null,
            },
            'grace_ends_at' => $subscription->grace_ends_at?->toISOString(),
            'started_by' => $subscription->purchased_by === null ? 'support' : ($isPurchaser ? 'me' : 'partner'),
            // Only the purchaser can cancel / change plan (their store account is billed).
            'can_manage' => $isPurchaser && $subscription->provider !== 'manual',
            'management_url' => $isPurchaser ? $provider?->managementUrl($subscription) : null,
        ];
    }

    public function transaction(SubscriptionTransaction $transaction): array
    {
        return [
            'id' => $transaction->id,
            'type' => $transaction->type,
            'amount' => $transaction->amount,
            'currency' => $transaction->currency,
            'occurred_at' => $transaction->occurred_at->toISOString(),
            'plan_name' => $transaction->planVersion?->plan?->name,
            'provider' => $transaction->provider,
            'is_test' => (bool) ($transaction->metadata['test'] ?? false),
        ];
    }
}
