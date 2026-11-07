<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SubscriptionPurchaseIntent extends Model
{
    protected $guarded = ['*'];

    protected function casts(): array
    {
        return ['expires_at' => 'datetime', 'consumed_at' => 'datetime'];
    }

    public function planVersion(): BelongsTo
    {
        return $this->belongsTo(SubscriptionPlanVersion::class, 'subscription_plan_version_id');
    }
}
