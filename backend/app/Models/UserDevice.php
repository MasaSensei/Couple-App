<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class UserDevice extends Model
{
    protected $fillable = [
        'user_id',
        'device_identifier',
        'device_name',
        'platform',
        'public_key',
        'last_seen_at',
        'revoked_at',
    ];

    protected function casts(): array
    {
        return [
            'last_seen_at' => 'datetime',
            'revoked_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function coupleKeyPackages(): HasMany
    {
        return $this->hasMany(
            CoupleKeyPackage::class,
            'device_id',
        );
    }
}
