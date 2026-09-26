<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Relations\HasMany;

class MemoryComment extends Model
{
    use HasFactory;
    use SoftDeletes;

    protected $fillable = [
        'memory_id',
        'user_id',
        'body',
    ];

    public function memory(): BelongsTo
    {
        return $this->belongsTo(
            Memory::class
        );
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(
            User::class
        );
    }

    public function comments(): HasMany
    {
        return $this->hasMany(
            MemoryComment::class,
        );
    }
}
