<?php

namespace App\Services\Billing\Providers;

class PaymentProviderRegistry
{
    /** Provider keys the API accepts. `manual` is admin-only and has no provider. */
    public const KEYS = ['mock', 'google_play', 'app_store'];

    public function __construct(
        private readonly MockPaymentProvider $mock,
        private readonly GooglePlayProvider $googlePlay,
        private readonly AppStoreProvider $appStore,
    ) {}

    public function get(string $key): ?PaymentProvider
    {
        return match ($key) {
            'mock' => $this->mock,
            'google_play' => $this->googlePlay,
            'app_store' => $this->appStore,
            default => null,
        };
    }

    /** @return list<string> */
    public function enabledKeys(): array
    {
        return array_values(array_filter(self::KEYS, fn (string $key) => $this->get($key)->isEnabled()));
    }
}
