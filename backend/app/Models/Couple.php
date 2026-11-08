<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class Couple extends Model
{
    use HasFactory;

    protected $fillable = [
        'invite_code',
        'relationship_started_at',
    ];

    protected function casts(): array
    {
        return [
            'relationship_started_at' => 'date',
        ];
    }

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

    public function keyPackages(): HasMany
    {
        return $this->hasMany(
            CoupleKeyPackage::class,
        );
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(CoupleSubscription::class);
    }

    public function hasMember(User $user): bool
    {
        return $this->members()->where('user_id', $user->id)->exists();
    }

    /**
     * Opaque id given to the store at purchase (Google obfuscatedAccountId,
     * Apple appAccountToken). Random, so it reveals nothing about the couple,
     * and stable, so a store purchase can be matched back to this couple only.
     */
    public function billingAccountToken(): string
    {
        if ($this->billing_account_token === null) {
            static::whereKey($this->id)->whereNull('billing_account_token')
                ->update(['billing_account_token' => (string) Str::uuid()]);
            $this->billing_account_token = static::whereKey($this->id)->value('billing_account_token');
        }

        return $this->billing_account_token;
    }
}
