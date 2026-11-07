<?php

namespace App\Services\Billing\Providers;

use App\Models\CoupleSubscription;
use Illuminate\Http\Request;

/**
 * Google Play Billing — NOT INTEGRATED YET (no Play Console credentials).
 *
 * Registered so the rest of the system (plans' `provider_products`, the API,
 * management links) is already provider-aware, but every server call fails
 * closed with PaymentProviderUnavailable: nothing can be granted through it.
 *
 * To integrate (docs/billing/subscriptions.md §9):
 *  - verifyPurchase/fetchSubscription: purchases.subscriptionsv2.get with a
 *    service-account token; check packageName, lineItems[].productId,
 *    externalAccountIdentifiers.obfuscatedExternalAccountId == the couple's
 *    billing_account_token, subscriptionState → normalised state,
 *    linkedPurchaseToken → replacesSubscriptionId; then acknowledge.
 *  - parseWebhook: Real-time developer notifications via Pub/Sub push; verify
 *    the Google-signed OIDC JWT (audience = pubsub_audience), use the Pub/Sub
 *    messageId as event id.
 *  - cancelRenewal: purchases.subscriptions.cancel is possible, but the store
 *    UI is the default (null) so users keep control in Google Play.
 */
class GooglePlayProvider implements PaymentProvider
{
    public function key(): string
    {
        return 'google_play';
    }

    public function isEnabled(): bool
    {
        return false; // flip only together with a real implementation
    }

    public function verifyPurchase(string $productId, string $purchaseToken): ProviderSubscriptionState
    {
        throw new PaymentProviderUnavailable('Google Play purchases are not available yet.');
    }

    public function fetchSubscription(string $subscriptionId): ProviderSubscriptionState
    {
        throw new PaymentProviderUnavailable('Google Play is not integrated yet.');
    }

    public function parseWebhook(Request $request): WebhookNotification
    {
        throw new InvalidWebhookSignature('Google Play notifications are not configured.');
    }

    public function cancelRenewal(CoupleSubscription $subscription): ?ProviderSubscriptionState
    {
        return null;
    }

    public function managementUrl(CoupleSubscription $subscription): ?string
    {
        $package = config('billing.providers.google_play.package_name');
        $product = $subscription->planVersion?->productIdFor('google_play');

        return $package && $product
            ? 'https://play.google.com/store/account/subscriptions?sku='.urlencode($product).'&package='.urlencode($package)
            : 'https://play.google.com/store/account/subscriptions';
    }
}
