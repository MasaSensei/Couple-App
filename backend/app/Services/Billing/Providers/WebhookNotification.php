<?php

namespace App\Services\Billing\Providers;

use Illuminate\Support\Carbon;

/**
 * A provider notification after its signature was verified. It only tells
 * us *which* subscription changed; the new state is always re-fetched from
 * the provider, so a delayed or replayed notification cannot roll a
 * subscription back.
 */
final class WebhookNotification
{
    public function __construct(
        public readonly string $eventId,
        public readonly string $type,
        public readonly ?string $subscriptionId,
        public readonly ?Carbon $occurredAt,
        public readonly array $payload,
    ) {}
}
