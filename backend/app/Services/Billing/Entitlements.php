<?php

namespace App\Services\Billing;

/** Resolved entitlements of one couple at one moment. Immutable. */
final class Entitlements
{
    /**
     * @param  array<string, bool|int>  $values
     */
    public function __construct(
        public readonly array $values,
        public readonly string $planKey,
        public readonly ?int $subscriptionId,
    ) {}

    public function allows(string $key): bool
    {
        return ($this->values[$key] ?? false) === true;
    }

    public function limit(string $key): int
    {
        return (int) ($this->values[$key] ?? 0);
    }

    public function storageLimitBytes(): int
    {
        return $this->limit('storage_limit_bytes');
    }

    public function toArray(): array
    {
        return $this->values;
    }
}
