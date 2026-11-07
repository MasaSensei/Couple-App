<?php

namespace App\Services\Billing;

use App\Models\Couple;
use App\Models\CoupleSubscription;
use App\Models\SubscriptionEvent;
use App\Models\SubscriptionPlan;
use App\Models\User;
use App\Services\Billing\Providers\PaymentProviderRegistry;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * Manual subscription adjustments. Each needs `billing.manage` and a reason,
 * and is written to subscription_events with the admin as actor.
 *
 * Refunds are deliberately not here: money is returned in the store's own
 * console (Play Console / App Store), and the resulting refund arrives
 * through the provider like any other change.
 */
class AdminSubscriptionActions
{
    public function __construct(
        private readonly SubscriptionLifecycle $lifecycle,
        private readonly SubscriptionService $subscriptions,
        private readonly PaymentProviderRegistry $providers,
        private readonly EntitlementCatalog $catalog,
    ) {}

    /** Complimentary plan for a fixed number of days (support, compensation). */
    public function grant(Couple $couple, SubscriptionPlan $plan, int $days, User $admin, string $reason): CoupleSubscription
    {
        $this->authorize($admin, $reason);

        $version = $plan->publishedVersion ?? throw new RuntimeException('This plan has no published version.');

        if ($plan->is_free || $days < 1 || $days > 366) {
            throw new RuntimeException('Grant a paid plan for 1 to 366 days.');
        }

        return DB::transaction(function () use ($couple, $version, $days, $admin, $reason) {
            Couple::whereKey($couple->id)->lockForUpdate()->first();

            if (CoupleSubscription::where('couple_id', $couple->id)->live()->exists()) {
                throw new RuntimeException('This couple already has a subscription.');
            }

            $subscription = new CoupleSubscription;
            $subscription->forceFill([
                'couple_id' => $couple->id,
                'subscription_plan_version_id' => $version->id,
                'provider' => 'manual',
                'provider_subscription_id' => 'manual_'.str()->uuid(),
                'status' => 'active',
                'auto_renew' => false,
                'current_period_start' => now(),
                'current_period_end' => now()->addDays($days),
                'entitlements_snapshot' => $this->catalog->validate($version->entitlements ?? []),
            ])->save();

            SubscriptionEvent::record($couple, $subscription, 'admin_grant', "admin:{$admin->id}", [
                'to' => 'active', 'reason' => $reason, 'data' => ['days' => $days, 'plan_version_id' => $version->id],
            ]);

            return $subscription;
        });
    }

    public function extend(CoupleSubscription $subscription, int $days, User $admin, string $reason): CoupleSubscription
    {
        $this->authorize($admin, $reason);

        if ($subscription->provider !== 'manual' || $subscription->status !== 'active' || $days < 1 || $days > 366) {
            throw new RuntimeException('Only active manual grants can be extended (1–366 days). Store subscriptions are extended by the store.');
        }

        return $this->lifecycle->transition($subscription, 'active', "admin:{$admin->id}", $reason, [
            'current_period_end' => $subscription->current_period_end->copy()->addDays($days),
        ]);
    }

    /** Stops benefits (fraud, chargeback under review). Data is untouched. */
    public function suspend(CoupleSubscription $subscription, User $admin, string $reason): CoupleSubscription
    {
        $this->authorize($admin, $reason);

        return $this->lifecycle->transition($subscription, 'suspended', "admin:{$admin->id}", $reason, ['admin_suspended' => true]);
    }

    public function reinstate(CoupleSubscription $subscription, User $admin, string $reason): CoupleSubscription
    {
        $this->authorize($admin, $reason);

        if ($subscription->status !== 'suspended') {
            throw new RuntimeException('Only a suspended subscription can be reinstated.');
        }

        $this->lifecycle->transition($subscription, 'active', "admin:{$admin->id}", $reason, ['admin_suspended' => false]);

        // Store subscriptions: take whatever the store says now.
        return $subscription->provider === 'manual' ? $subscription : $this->resync($subscription, $admin, 'After reinstatement.');
    }

    /** Ends a manual grant now. */
    public function revoke(CoupleSubscription $subscription, User $admin, string $reason): CoupleSubscription
    {
        $this->authorize($admin, $reason);

        if ($subscription->provider !== 'manual') {
            throw new RuntimeException('Store subscriptions end through the store (refund/cancel there).');
        }

        return $this->lifecycle->transition($subscription, 'expired', "admin:{$admin->id}", $reason, ['ended_reason' => 'admin']);
    }

    public function resync(CoupleSubscription $subscription, User $admin, string $reason = 'Manual resync.'): CoupleSubscription
    {
        $this->authorize($admin, $reason);

        $provider = $this->providers->get($subscription->provider)
            ?? throw new RuntimeException('Manual grants have no provider to sync with.');

        return $this->subscriptions->applyProviderState(
            $provider->fetchSubscription($subscription->provider_subscription_id),
            "admin:{$admin->id}",
            $subscription->couple,
        );
    }

    private function authorize(User $admin, string $reason): void
    {
        if (! $admin->hasAdminPermission('billing.manage')) {
            throw new AuthorizationException('Missing the billing.manage permission.');
        }

        if (mb_strlen(trim($reason)) < 5) {
            throw new RuntimeException('A reason (at least 5 characters) is required for the audit log.');
        }
    }
}
