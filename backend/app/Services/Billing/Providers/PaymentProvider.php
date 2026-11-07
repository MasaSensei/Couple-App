<?php

namespace App\Services\Billing\Providers;

use App\Models\CoupleSubscription;
use Illuminate\Http\Request;

/**
 * One store / payment provider. Every method talks to the provider's own
 * server; nothing the app sends is trusted beyond the opaque token.
 */
interface PaymentProvider
{
    public function key(): string;

    public function isEnabled(): bool;

    /**
     * Server-side verification of a purchase the app just made.
     *
     * @throws PurchaseVerificationFailed token unknown, wrong product/app, not paid
     * @throws PaymentProviderUnavailable provider down or not configured
     */
    public function verifyPurchase(string $productId, string $purchaseToken): ProviderSubscriptionState;

    /** Current authoritative state of a known subscription (reconciliation, webhooks). */
    public function fetchSubscription(string $subscriptionId): ProviderSubscriptionState;

    /**
     * Verifies the notification's signature and extracts its identifiers.
     *
     * @throws InvalidWebhookSignature
     */
    public function parseWebhook(Request $request): WebhookNotification;

    /**
     * Turns auto-renew off through the provider's server API when the
     * provider allows that; null means the subscriber must do it in the
     * store's own subscription settings (see managementUrl()).
     */
    public function cancelRenewal(CoupleSubscription $subscription): ?ProviderSubscriptionState;

    /** Where the purchaser manages/cancels this subscription, if outside the app. */
    public function managementUrl(CoupleSubscription $subscription): ?string;
}
