<?php

namespace App\Services\Billing;

use App\Models\Couple;
use App\Models\CoupleSubscription;
use App\Models\SubscriptionPlan;

/**
 * The single place that answers "what may this couple do?".
 *
 * Entitlements belong to the Couple. A user only has them through current
 * membership, so a partner who leaves stops having them and a new couple
 * never inherits them. Callers ask allows()/limit() for a key; nothing in
 * the app compares plan names.
 *
 * Resolution: definition defaults < Free plan's published version <
 * the live subscription's snapshot (taken when it was bought, so later
 * plan edits never change it). A paid snapshot can never give less than
 * Free: numbers take the larger value, booleans are OR-ed.
 */
class EntitlementService
{
    public function __construct(
        private readonly EntitlementCatalog $catalog,
    ) {}

    public function forCouple(Couple $couple): Entitlements
    {
        $values = $this->catalog->defaults();
        $planKey = 'free';

        $free = SubscriptionPlan::free()?->publishedVersion;
        if ($free !== null) {
            // Free replaces the code defaults (admins may lower them too).
            foreach ($free->entitlements ?? [] as $key => $value) {
                if ($this->catalog->type($key) !== null) {
                    $values[$key] = $value;
                }
            }
        }

        $subscription = $this->entitledSubscription($couple);

        if ($subscription !== null) {
            $values = $this->merge($values, $subscription->entitlements_snapshot ?? []);
            $planKey = $subscription->planVersion->plan->key;
        }

        return new Entitlements($values, $planKey, $subscription?->id);
    }

    /** The couple's live subscription if it currently grants benefits. */
    public function entitledSubscription(Couple $couple): ?CoupleSubscription
    {
        $subscription = CoupleSubscription::query()
            ->where('couple_id', $couple->id)
            ->live()
            ->with('planVersion.plan')
            ->first();

        return $subscription?->isEntitled() ? $subscription : null;
    }

    private function merge(array $base, array $overlay): array
    {
        foreach ($overlay as $key => $value) {
            $type = $this->catalog->type($key);

            if ($type === null) {
                continue; // a key removed from code is ignored, never trusted
            }

            $base[$key] = $type === 'boolean'
                ? (bool) ($base[$key] ?? false) || $value === true
                : max((int) ($base[$key] ?? 0), (int) $value);
        }

        return $base;
    }
}
