<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use LogicException;

/** Append-only audit trail of subscription changes. */
class SubscriptionEvent extends Model
{
    public const UPDATED_AT = null;

    protected $guarded = ['*'];

    protected function casts(): array
    {
        return ['data' => 'array', 'created_at' => 'datetime'];
    }

    protected static function booted(): void
    {
        static::updating(fn () => throw new LogicException('Subscription events are append-only.'));
        static::deleting(fn () => throw new LogicException('Subscription events are append-only.'));
    }

    /**
     * @param  array{from?: ?string, to?: ?string, reason?: ?string, data?: ?array}  $attributes
     */
    public static function record(Couple|int $couple, ?CoupleSubscription $subscription, string $type, string $actor, array $attributes = []): self
    {
        return static::forceCreate([
            'couple_id' => $couple instanceof Couple ? $couple->id : $couple,
            'couple_subscription_id' => $subscription?->id,
            'type' => $type,
            'actor' => $actor,
            'from_status' => $attributes['from'] ?? null,
            'to_status' => $attributes['to'] ?? null,
            'reason' => isset($attributes['reason']) ? mb_substr($attributes['reason'], 0, 500) : null,
            'data' => $attributes['data'] ?? null,
        ]);
    }

    public function subscription(): BelongsTo
    {
        return $this->belongsTo(CoupleSubscription::class, 'couple_subscription_id');
    }
}
