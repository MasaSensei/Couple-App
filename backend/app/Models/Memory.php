<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Memory extends Model
{
    use HasFactory;
    use SoftDeletes;

    protected $fillable = [
        'couple_id',
        'created_by',
        'date_id',
        'title',
        'description',
        'memory_date',
        'location_name',
        'location_address',
        'latitude',
        'longitude',
    ];

    protected function casts(): array
    {
        return [
            'memory_date' => 'date',
            'latitude' => 'decimal:7',
            'longitude' => 'decimal:7',
        ];
    }

    public function couple(): BelongsTo
    {
        return $this->belongsTo(
            Couple::class
        );
    }

    public function createdBy(): BelongsTo
    {
        return $this->belongsTo(
            User::class,
            'created_by'
        );
    }

    public function date(): BelongsTo
    {
        return $this->belongsTo(
            Date::class
        );
    }

    public function photos(): HasMany
    {
        return $this->hasMany(MemoryPhoto::class);
    }

    public function comments(): HasMany
    {
        return $this->hasMany(MemoryComment::class);
    }
}
