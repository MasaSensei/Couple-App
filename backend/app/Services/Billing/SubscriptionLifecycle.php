<?php

namespace App\Services\Billing;

use App\Models\CoupleSubscription;
use App\Models\SubscriptionEvent;
use LogicException;

/**
 * The only code that changes a subscription's status.
 *
 *   pending ──► active ◄──► cancelled (renewal off; benefits until period end)
 *                 │ ▲            │
 *                 ▼ │            ▼
 *            grace_period ──► payment_failed ──► expired (terminal*)
 *                 suspended (paused / admin) ──► active | expired
 *
 * Cancellation is not expiration: `cancelled` keeps every benefit until
 * `current_period_end`; only then does it become `expired`. No transition
 * ever deletes data. (*) `expired` only re-opens when the provider itself
 * reports the same subscription active again (Apple re-subscribe keeps the
 * original transaction id).
 */
class SubscriptionLifecycle
{
    public const TRANSITIONS = [
        'pending' => ['pending', 'active', 'cancelled', 'grace_period', 'payment_failed', 'expired'],
        'active' => ['active', 'cancelled', 'grace_period', 'payment_failed', 'suspended', 'expired'],
        'cancelled' => ['cancelled', 'active', 'suspended', 'expired'],
        'grace_period' => ['grace_period', 'active', 'cancelled', 'payment_failed', 'suspended', 'expired'],
        'payment_failed' => ['payment_failed', 'active', 'cancelled', 'expired'],
        'suspended' => ['suspended', 'active', 'cancelled', 'expired'],
        'expired' => ['expired'],
    ];

    public function canTransition(string $from, string $to, string $actor): bool
    {
        if ($from === 'expired' && $to === 'active') {
            return str_starts_with($actor, 'provider:');
        }

        return in_array($to, self::TRANSITIONS[$from] ?? [], true);
    }

    /**
     * Applies a status (and any period fields) and writes the audit event.
     *
     * @param  array<string, mixed>  $attributes  other columns to set with it
     */
    public function transition(CoupleSubscription $subscription, string $to, string $actor, ?string $reason = null, array $attributes = [], array $data = []): CoupleSubscription
    {
        $from = $subscription->status;

        if (! $this->canTransition($from, $to, $actor)) {
            throw new LogicException("Subscription #{$subscription->id} cannot go from {$from} to {$to}.");
        }

        $attributes = ['status' => $to, ...$attributes];

        if ($to === 'expired' && $from !== 'expired') {
            $attributes += ['ended_at' => now(), 'ended_reason' => 'expired', 'auto_renew' => false];
        }

        if ($to !== 'expired' && $from === 'expired') {
            $attributes += ['ended_at' => null, 'ended_reason' => null];
        }

        if ($to === 'cancelled' && $from !== 'cancelled') {
            $attributes += ['cancelled_at' => now(), 'auto_renew' => false];
        }

        if (in_array($to, ['active', 'grace_period'], true) && $from === 'cancelled') {
            $attributes += ['cancelled_at' => null];
        }

        $subscription->forceFill($attributes);
        $changed = $subscription->getDirty();
        $subscription->save();

        if ($from !== $to || array_diff_key($changed, ['last_synced_at' => 1, 'updated_at' => 1, 'provider_state_at' => 1]) !== []) {
            SubscriptionEvent::record($subscription->couple_id, $subscription, $from === $to ? 'updated' : 'status_changed', $actor, [
                'from' => $from,
                'to' => $to,
                'reason' => $reason,
                'data' => $data + ['changed' => array_keys(array_diff_key($changed, ['updated_at' => 1]))],
            ]);
        }

        return $subscription;
    }
}
