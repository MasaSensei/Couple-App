<?php

namespace App\Services\Billing\Providers;

use App\Models\SubscriptionPlanVersion;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * A fake app store living in the cache, for development and tests only.
 * It plays the role of Google Play / App Store servers: it holds purchases,
 * renews, fails, refunds them, and sends signed webhooks. The app server
 * talks to it only through MockPaymentProvider, exactly like a real store.
 *
 * Disabled unless billing.providers.mock.enabled (never in production).
 */
class MockStore
{
    private const PREFIX = 'billing:mock-store:';

    public function purchase(string $productId, string $accountToken, ?string $replacesToken = null): array
    {
        $version = $this->versionFor($productId);
        $start = now();
        $token = 'mock_'.Str::random(32);

        $purchase = [
            'token' => $token,
            'product_id' => $productId,
            'account_token' => $accountToken,
            'state' => 'active',
            'auto_renew' => true,
            'period_start' => $start->toISOString(),
            'period_end' => $version->periodEnd($start)->toISOString(),
            'grace_ends_at' => null,
            'replaces' => $replacesToken,
            'revocation' => null,
            'state_at' => $this->nextStateAt(null),
            'transactions' => [$this->transaction('purchase', $version)],
        ];

        if ($replacesToken !== null) {
            $this->update($replacesToken, fn (array $old) => [...$old, 'state' => 'expired', 'auto_renew' => false]);
        }

        $this->put($purchase);

        return $purchase;
    }

    public function find(string $token): ?array
    {
        return Cache::get(self::PREFIX.$token);
    }

    public function renew(string $token): array
    {
        return $this->update($token, function (array $p) {
            $version = $this->versionFor($p['product_id']);
            $start = Carbon::parse($p['period_end']);

            return [...$p, 'state' => 'active', 'grace_ends_at' => null,
                'period_start' => $start->toISOString(),
                'period_end' => $version->periodEnd($start)->toISOString(),
                'transactions' => [...$p['transactions'], $this->transaction('renewal', $version, $start)]];
        });
    }

    /** Renewal charge failed: the store keeps retrying during its grace period. */
    public function failRenewal(string $token, ?int $graceDays = null): array
    {
        return $this->update($token, fn (array $p) => [...$p, 'state' => 'grace_period',
            'grace_ends_at' => Carbon::parse($p['period_end'])->addDays($graceDays ?? config('billing.default_grace_period_days'))->toISOString()]);
    }

    /** Grace ran out and payment still fails ("account hold"). */
    public function hold(string $token): array
    {
        return $this->update($token, fn (array $p) => [...$p, 'state' => 'on_hold']);
    }

    public function pause(string $token): array
    {
        return $this->update($token, fn (array $p) => [...$p, 'state' => 'paused']);
    }

    public function cancel(string $token): array
    {
        return $this->update($token, fn (array $p) => [...$p, 'state' => 'cancelled', 'auto_renew' => false]);
    }

    public function resume(string $token): array
    {
        return $this->update($token, fn (array $p) => [...$p, 'state' => 'active', 'auto_renew' => true]);
    }

    public function expire(string $token): array
    {
        return $this->update($token, fn (array $p) => [...$p, 'state' => 'expired', 'auto_renew' => false]);
    }

    public function refund(string $token, bool $chargeback = false): array
    {
        return $this->update($token, function (array $p) use ($chargeback) {
            $last = end($p['transactions']);

            return [...$p, 'state' => 'revoked', 'auto_renew' => false,
                'revocation' => $chargeback ? 'chargeback' : 'refunded',
                'transactions' => [...$p['transactions'], [
                    'id' => $last['id'],
                    'type' => $chargeback ? 'chargeback' : 'refund',
                    'amount' => -$last['amount'],
                    'currency' => $last['currency'],
                    'occurred_at' => now()->toISOString(),
                ]]];
        });
    }

    /** Simulates the store's server being unreachable. */
    public function setOutage(bool $down): void
    {
        Cache::forever(self::PREFIX.'outage', $down);
    }

    public function isDown(): bool
    {
        return (bool) Cache::get(self::PREFIX.'outage', false);
    }

    /**
     * A webhook body + signature exactly as the store would POST it.
     *
     * @return array{body: string, signature: string, event_id: string}
     */
    public function webhook(string $token, string $type, ?string $eventId = null): array
    {
        $eventId ??= 'evt_'.Str::random(24);
        $body = json_encode([
            'event_id' => $eventId,
            'type' => $type,
            'subscription_id' => $token,
            'occurred_at' => now()->toISOString(),
        ], JSON_THROW_ON_ERROR);

        return [
            'body' => $body,
            'signature' => hash_hmac('sha256', $body, (string) config('billing.providers.mock.webhook_secret')),
            'event_id' => $eventId,
        ];
    }

    private function update(string $token, callable $change): array
    {
        $purchase = $this->find($token) ?? throw new RuntimeException('Unknown mock purchase.');
        $updated = $change($purchase);
        $updated['state_at'] = $this->nextStateAt($purchase['state_at']);
        $this->put($updated);

        return $updated;
    }

    private function put(array $purchase): void
    {
        Cache::forever(self::PREFIX.$purchase['token'], $purchase);
    }

    /** Strictly increasing, like a real store's event time. */
    private function nextStateAt(?string $previous): string
    {
        $now = now()->startOfSecond();

        if ($previous !== null && $now->lte(Carbon::parse($previous))) {
            $now = Carbon::parse($previous)->addSecond();
        }

        return $now->toISOString();
    }

    private function transaction(string $type, SubscriptionPlanVersion $version, ?Carbon $at = null): array
    {
        return [
            'id' => 'mock_txn_'.Str::random(20),
            'type' => $type,
            'amount' => $version->price_amount,
            'currency' => $version->currency,
            'occurred_at' => ($at ?? now())->toISOString(),
        ];
    }

    /** The mock "store console" prices products like the latest version selling them. */
    private function versionFor(string $productId): SubscriptionPlanVersion
    {
        return SubscriptionPlanVersion::query()
            ->whereIn('status', ['published', 'archived'])
            ->where('provider_products->mock', $productId)
            ->orderByRaw("status = 'published' DESC")
            ->orderByDesc('id')
            ->first() ?? throw new PurchaseVerificationFailed('Unknown product.');
    }
}
