<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/** Photo Booth template metadata. Layout and rendering live in the Flutter app. */
class PhotoBoothTemplate extends Model
{
    protected $fillable = ['name', 'status', 'is_premium', 'sort_order'];

    protected function casts(): array
    {
        return [
            'is_premium' => 'boolean',
            'version' => 'integer',
            'photo_slots' => 'integer',
            'sort_order' => 'integer',
        ];
    }

    public function scopeSelectable(Builder $query): Builder
    {
        return $query->where('status', 'active')->orderBy('sort_order');
    }
}
