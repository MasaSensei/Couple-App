<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Couple extends Model
{
    use HasFactory;

    protected $fillable = [
        'invite_code',
    ];

    public function members(): HasMany
    {
        return $this->hasMany(CoupleMember::class);
    }

    public function invitations(): HasMany
    {
        return $this->hasMany(CoupleInvitation::class);
    }

    public function dates(): HasMany
    {
        return $this->hasMany(Date::class);
    }

    public function memories(): HasMany
    {
        return $this->hasMany(Memory::class);
    }
}
