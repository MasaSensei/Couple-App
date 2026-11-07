<?php

namespace App\Models;

use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Illuminate\Database\Eloquent\Relations\HasOne;

#[Fillable(['name', 'email', 'password'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable implements FilamentUser
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_admin' => 'boolean',
            'admin_permissions' => 'array',
        ];
    }

    /** Admin permissions beyond panel access. See docs/billing/subscriptions.md §10. */
    public const ADMIN_PERMISSIONS = ['billing.view', 'billing.manage', 'plans.manage'];

    public function hasAdminPermission(string $permission): bool
    {
        return $this->is_admin === true
            && in_array($permission, $this->admin_permissions ?? [], true);
    }

    public function coupleMemberships(): HasMany
    {
        return $this->hasMany(CoupleMember::class);
    }

    public function canAccessPanel(Panel $panel): bool
    {
        // Fail closed: an unloaded/null flag must deny, not error.
        return $this->is_admin === true;
    }

    public function sentCoupleInvitations(): HasMany
    {
        return $this->hasMany(
            CoupleInvitation::class,
            'invited_by'
        );
    }

    public function createdDates(): HasMany
    {
        return $this->hasMany(
            Date::class,
            'created_by'
        );
    }

    public function createdMemories(): HasMany
    {
        return $this->hasMany(Memory::class, 'created_by');
    }

    public function dateComments(): HasMany
    {
        return $this->hasMany(DateComment::class);
    }

    public function uploadedMemoryPhotos(): HasMany
    {
        return $this->hasMany(
            MemoryPhoto::class,
            'uploaded_by'
        );
    }

    public function memoryComments(): HasMany
    {
        return $this->hasMany(
            MemoryComment::class
        );
    }

    public function devices()
    {
        return $this->hasMany(UserDevice::class);
    }

    public function couple(): HasOne
    {
        return $this->hasOne(Couple::class);
    }
}
