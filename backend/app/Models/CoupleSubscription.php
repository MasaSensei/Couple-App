<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

/**
 * A subscription owned by a Couple, not by the partner who paid.
 *
 * `status` is only changed through SubscriptionLifecycle, which validates
 * the transition and writes a SubscriptionEvent. Nothing here is
 * mass-assignable and nothing is ever taken from a client request.
 */
class CoupleSubscription extends Model
{
    public const STATUSES = ['pending', 'active', 'grace_period', 'cancelled', 'expired', 'payment_failed', 'suspended'];

    /** Statuses that occupy the couple's single "live" slot (see the partial unique index). */
    public const LIVE = ['pending', 'active', 'grace_period', 'cancelled', 'payment_failed', 'suspended'];

    protected $guarded = ['*'];

    protected function casts(): array
    {
        return [
            'auto_renew' => 'boolean',
            'current_period_start' => 'datetime',
            'current_period_end' => 'datetime',
            'grace_ends_at' => 'datetime',
            'cancelled_at' => 'datetime',
            'ended_at' => 'datetime',
            'provider_state_at' => 'datetime',
            'last_synced_at' => 'datetime',
            'entitlements_snapshot' => 'array',
        ];
    }

    public function couple(): BelongsTo
    {
        return $this->belongsTo(Couple::class);
    }

    public function planVersion(): BelongsTo
    {
        return $this->belongsTo(SubscriptionPlanVersion::class, 'subscription_plan_version_id');
    }

    public function purchaser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'purchased_by');
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(SubscriptionTransaction::class);
    }

    public function events(): HasMany
    {
        return $this->hasMany(SubscriptionEvent::class);
    }

    public function scopeLive(Builder $query): Builder
    {
        return $query->whereIn('status', self::LIVE);
    }

    /**
     * Whether the couple gets this subscription's entitlements at $at.
     * Purely time-based on top of the status, so benefits end on time even
     * if the scheduler that moves statuses along runs late.
     */
    public function isEntitled(?\DateTimeInterface $at = null): bool
    {
        $now = $at ? Carbon::instance($at) : now();

        return match ($this->status) {
            // Auto-renewing: a short leeway past the period end while the
            // store's renewal confirmation is on its way (delay / outage).
            'active' => $this->current_period_end === null
                || $now->lt($this->current_period_end->copy()->addHours(
                    $this->auto_renew ? config('billing.renewal_leeway_hours') : 0,
                )),
            // Renewal cancelled: benefits continue exactly until the paid period ends.
            'cancelled' => $this->current_period_end !== null && $now->lt($this->current_period_end),
            'grace_period' => $this->grace_ends_at !== null && $now->lt($this->grace_ends_at),
            default => false,
        };
    }
}
