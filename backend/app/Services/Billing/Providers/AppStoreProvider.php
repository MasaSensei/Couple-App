<?php

namespace App\Services\Billing\Providers;

use App\Models\CoupleSubscription;
use Illuminate\Http\Request;

/**
 * Apple In-App Purchase — NOT INTEGRATED YET (no App Store Connect key).
 *
 * Fails closed like GooglePlayProvider. To integrate
 * (docs/billing/subscriptions.md §9):
 *  - verifyPurchase/fetchSubscription: App Store Server API
 *    "Get All Subscription Statuses" by originalTransactionId with an ES256
 *    JWT (issuer_id, key_id, private_key); verify each JWS
 *    signedTransactionInfo/signedRenewalInfo chain against Apple's root CA;
 *    check bundleId, productId, appAccountToken == billing_account_token.
 *  - parseWebhook: App Store Server Notifications V2 — verify the JWS
 *    signedPayload chain; notificationUUID is the event id.
 *  - cancelRenewal: not possible server-side; always null (Settings app).
 */
class AppStoreProvider implements PaymentProvider
{
    public function key(): string
    {
        return 'app_store';
    }

    public function isEnabled(): bool
    {
        return false;
    }

    public function verifyPurchase(string $productId, string $purchaseToken): ProviderSubscriptionState
    {
        throw new PaymentProviderUnavailable('App Store purchases are not available yet.');
    }

    public function fetchSubscription(string $subscriptionId): ProviderSubscriptionState
    {
        throw new PaymentProviderUnavailable('The App Store is not integrated yet.');
    }

    public function parseWebhook(Request $request): WebhookNotification
    {
        throw new InvalidWebhookSignature('App Store notifications are not configured.');
    }

    public function cancelRenewal(CoupleSubscription $subscription): ?ProviderSubscriptionState
    {
        return null;
    }

    public function managementUrl(CoupleSubscription $subscription): ?string
    {
        return 'https://apps.apple.com/account/subscriptions';
    }
}
