<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** A money movement reported (and verified) by a provider. Never holds card data. */
class SubscriptionTransaction extends Model
{
    protected $guarded = ['*'];

    protected function casts(): array
    {
        return [
            'amount' => 'integer',
            'occurred_at' => 'datetime',
            'metadata' => 'array',
        ];
    }

    public function subscription(): BelongsTo
    {
        return $this->belongsTo(CoupleSubscription::class, 'couple_subscription_id');
    }

    public function planVersion(): BelongsTo
    {
        return $this->belongsTo(SubscriptionPlanVersion::class, 'subscription_plan_version_id');
    }
}
