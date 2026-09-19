<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Date extends Model
{
    use HasFactory;

    protected $fillable = [
        'couple_id',
        'created_by',
        'title',
        'description',
        'location',
        'scheduled_at',
        'status',
        'completed_at',
    ];

    protected function casts(): array
    {
        return [
            'scheduled_at' => 'datetime',
            'completed_at' => 'datetime',
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

    public function comments(): HasMany
    {
        return $this->hasMany(DateComment::class);
    }
}
