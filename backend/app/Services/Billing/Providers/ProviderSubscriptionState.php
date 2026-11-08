<?php

namespace App\Services\Billing\Providers;

use Illuminate\Support\Carbon;

/**
 * A subscription as the provider's own server reports it, normalised.
 * Only ever built from a server-side provider call (or the mock store),
 * never from anything the app sends.
 */
final class ProviderSubscriptionState
{
    /** Normalised provider states. */
    public const STATES = ['pending', 'active', 'cancelled', 'grace_period', 'on_hold', 'paused', 'expired', 'revoked'];

    /**
     * @param  list<array{id: string, type: string, amount: int, currency: string, occurred_at: Carbon}>  $transactions
     */
    public function __construct(
        public readonly string $provider,
        public readonly string $subscriptionId,
        public readonly string $productId,
        public readonly string $state,
        public readonly bool $autoRenew,
        public readonly ?Carbon $periodStart,
        public readonly ?Carbon $periodEnd,
        public readonly ?Carbon $graceEndsAt,
        public readonly ?string $accountToken,
        public readonly Carbon $stateAt,
        public readonly ?string $replacesSubscriptionId = null,
        public readonly array $transactions = [],
        public readonly ?string $revocationReason = null, // refunded | chargeback
        public readonly bool $isTest = false,
    ) {
        if (! in_array($state, self::STATES, true)) {
            throw new \InvalidArgumentException("Unknown provider state [{$state}].");
        }
    }

    /** Our lifecycle status for this provider state. */
    public function status(): string
    {
        // Not renewing and the paid period is over: that is an expiry, whatever
        // label the provider still shows.
        if ($this->isLapsed()) {
            return 'expired';
        }

        return match ($this->state) {
            'pending' => 'pending',
            'active' => $this->autoRenew ? 'active' : 'cancelled',
            'cancelled' => 'cancelled',
            'grace_period' => 'grace_period',
            'on_hold' => 'payment_failed',
            'paused' => 'suspended',
            'expired', 'revoked' => 'expired',
        };
    }

    private function isLapsed(): bool
    {
        return in_array($this->state, ['active', 'cancelled'], true)
            && ! $this->autoRenew
            && $this->periodEnd !== null
            && $this->periodEnd->isPast();
    }

    public function endedReason(): ?string
    {
        if ($this->isLapsed()) {
            return 'expired';
        }

        return match ($this->state) {
            'expired' => 'expired',
            'revoked' => $this->revocationReason ?? 'refunded',
            default => null,
        };
    }
}
