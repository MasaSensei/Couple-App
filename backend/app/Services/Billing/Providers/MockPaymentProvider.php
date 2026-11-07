<?php

namespace App\Services\Billing\Providers;

use App\Models\CoupleSubscription;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

/**
 * Talks to MockStore the way the real providers talk to Google/Apple:
 * server-side lookups by token and HMAC-signed webhooks. Development and
 * tests only — NOT a production payment integration.
 */
class MockPaymentProvider implements PaymentProvider
{
    public function __construct(
        private readonly MockStore $store,
    ) {}

    public function key(): string
    {
        return 'mock';
    }

    public function isEnabled(): bool
    {
        // Hard stop in production, whatever the env says.
        return (bool) config('billing.providers.mock.enabled') && ! app()->isProduction();
    }

    public function verifyPurchase(string $productId, string $purchaseToken): ProviderSubscriptionState
    {
        $state = $this->fetchSubscription($purchaseToken);

        if ($state->productId !== $productId) {
            throw new PurchaseVerificationFailed('The purchase is for a different product.');
        }

        return $state;
    }

    public function fetchSubscription(string $subscriptionId): ProviderSubscriptionState
    {
        $this->assertReachable();

        $purchase = $this->store->find($subscriptionId)
            ?? throw new PurchaseVerificationFailed('The store does not know this purchase.');

        return new ProviderSubscriptionState(
            provider: 'mock',
            subscriptionId: $purchase['token'],
            productId: $purchase['product_id'],
            state: $purchase['state'],
            autoRenew: $purchase['auto_renew'],
            periodStart: Carbon::parse($purchase['period_start']),
            periodEnd: Carbon::parse($purchase['period_end']),
            graceEndsAt: $purchase['grace_ends_at'] ? Carbon::parse($purchase['grace_ends_at']) : null,
            accountToken: $purchase['account_token'],
            stateAt: Carbon::parse($purchase['state_at']),
            replacesSubscriptionId: $purchase['replaces'],
            transactions: array_map(fn (array $t) => [...$t, 'occurred_at' => Carbon::parse($t['occurred_at'])], $purchase['transactions']),
            revocationReason: $purchase['revocation'],
            isTest: true,
        );
    }

    public function parseWebhook(Request $request): WebhookNotification
    {
        $expected = hash_hmac('sha256', $request->getContent(), (string) config('billing.providers.mock.webhook_secret'));

        if (! hash_equals($expected, (string) $request->header('X-Mock-Signature'))) {
            throw new InvalidWebhookSignature('Invalid mock webhook signature.');
        }

        $payload = json_decode($request->getContent(), true);

        if (! is_array($payload) || ! is_string($payload['event_id'] ?? null) || ! is_string($payload['type'] ?? null)) {
            throw new InvalidWebhookSignature('Malformed mock webhook.');
        }

        return new WebhookNotification(
            eventId: $payload['event_id'],
            type: $payload['type'],
            subscriptionId: $payload['subscription_id'] ?? null,
            occurredAt: isset($payload['occurred_at']) ? Carbon::parse($payload['occurred_at']) : null,
            payload: $payload,
        );
    }

    public function cancelRenewal(CoupleSubscription $subscription): ?ProviderSubscriptionState
    {
        $this->assertReachable();
        $this->store->cancel($subscription->provider_subscription_id);

        return $this->fetchSubscription($subscription->provider_subscription_id);
    }

    public function managementUrl(CoupleSubscription $subscription): ?string
    {
        return null; // managed in-app
    }

    private function assertReachable(): void
    {
        if (! $this->isEnabled()) {
            throw new PaymentProviderUnavailable('The mock store is disabled.');
        }

        if ($this->store->isDown()) {
            throw new PaymentProviderUnavailable('The store is not reachable right now.');
        }
    }
}
