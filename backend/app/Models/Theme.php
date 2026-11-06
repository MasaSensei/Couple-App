<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/** Theme catalog metadata. The visual definition lives in the Flutter app. */
class Theme extends Model
{
    public const STATUSES = ['active', 'hidden', 'retired'];

    protected $fillable = ['name', 'status', 'is_premium', 'sort_order'];

    protected function casts(): array
    {
        return [
            'options' => 'array',
            'is_default' => 'boolean',
            'is_premium' => 'boolean',
            'version' => 'integer',
            'sort_order' => 'integer',
        ];
    }

    public function scopeSelectable(Builder $query): Builder
    {
        return $query->where('status', 'active')->orderBy('sort_order');
    }

    public static function default(): self
    {
        return static::where('is_default', true)->firstOrFail();
    }
}
