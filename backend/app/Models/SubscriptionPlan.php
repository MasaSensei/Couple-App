<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class SubscriptionPlan extends Model
{
    protected $fillable = ['key', 'name', 'description', 'status', 'is_free', 'sort_order'];

    protected function casts(): array
    {
        return [
            'is_free' => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    public function versions(): HasMany
    {
        return $this->hasMany(SubscriptionPlanVersion::class);
    }

    public function publishedVersion(): HasOne
    {
        return $this->hasOne(SubscriptionPlanVersion::class)->where('status', 'published');
    }

    /** Plans shown to users: active and with a published version. */
    public function scopeOffered(Builder $query): Builder
    {
        return $query->where('status', 'active')->whereHas('publishedVersion')->orderBy('sort_order')->orderBy('id');
    }

    public static function free(): ?self
    {
        return static::where('is_free', true)->orderBy('id')->first();
    }
}
