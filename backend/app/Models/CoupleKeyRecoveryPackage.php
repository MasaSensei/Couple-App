<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CoupleKeyRecoveryPackage extends Model
{
    protected $fillable = [
        'user_id',
        'couple_id',
        'key_id',
        'format_version',
        'nonce',
        'ciphertext',
        'mac',
    ];

    protected function casts(): array
    {
        return [
            'format_version' => 'integer',
        ];
    }
}
