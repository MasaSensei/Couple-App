<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;
use LogicException;

/**
 * A plan's price, interval and entitlements at one point in time.
 *
 * Once published, a version never changes: subscriptions point at it and
 * copy its entitlements, so editing a price or quota later cannot rewrite
 * what an existing subscriber bought. Admins publish a new version instead.
 */
class SubscriptionPlanVersion extends Model
{
    public const INTERVALS = ['none', 'month', 'year'];

    /** Fields that are frozen once the version leaves `draft`. */
    private const FROZEN = ['price_amount', 'currency', 'billing_interval', 'billing_interval_count', 'entitlements', 'provider_products', 'version', 'subscription_plan_id'];

    protected $fillable = [
        'subscription_plan_id', 'version', 'price_amount', 'currency',
        'billing_interval', 'billing_interval_count', 'entitlements', 'provider_products',
    ];

    protected function casts(): array
    {
        return [
            'price_amount' => 'integer',
            'billing_interval_count' => 'integer',
            'version' => 'integer',
            'entitlements' => 'array',
            'provider_products' => 'array',
            'published_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::updating(function (SubscriptionPlanVersion $version): void {
            if ($version->getOriginal('status') !== 'draft' && $version->isDirty(self::FROZEN)) {
                throw new LogicException('A published plan version cannot be changed; publish a new version instead.');
            }
            if ($version->getOriginal('status') === 'archived' && $version->isDirty('status')) {
                throw new LogicException('An archived plan version cannot be re-published.');
            }
        });

        static::deleting(function (SubscriptionPlanVersion $version): void {
            if ($version->status !== 'draft') {
                throw new LogicException('Only draft plan versions can be deleted.');
            }
        });
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(SubscriptionPlan::class, 'subscription_plan_id');
    }

    public function productIdFor(string $provider): ?string
    {
        return $this->provider_products[$provider] ?? null;
    }

    public function isRecurring(): bool
    {
        return $this->billing_interval !== 'none';
    }

    /** End of one billing period starting at $from. */
    public function periodEnd(\DateTimeInterface $from): Carbon
    {
        $start = Carbon::instance($from);

        return match ($this->billing_interval) {
            'month' => $start->copy()->addMonthsNoOverflow($this->billing_interval_count),
            'year' => $start->copy()->addYearsNoOverflow($this->billing_interval_count),
            default => throw new LogicException('A non-recurring plan has no billing period.'),
        };
    }
}
