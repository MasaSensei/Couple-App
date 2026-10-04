<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CoupleKeyPackage extends Model
{
    protected $fillable = [
        'couple_id',
        'device_id',
        'key_id',
        'encryption_version',
        'ephemeral_public_key',
        'nonce',
        'ciphertext',
        'mac',
        'revoked_at',
    ];

    protected function casts(): array
    {
        return [
            'encryption_version' => 'integer',
            'revoked_at' => 'datetime',
        ];
    }

    public function couple(): BelongsTo
    {
        return $this->belongsTo(Couple::class);
    }

    public function device(): BelongsTo
    {
        return $this->belongsTo(
            UserDevice::class,
            'device_id',
        );
    }
}
