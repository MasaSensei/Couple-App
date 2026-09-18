<?php

namespace App\Policies;

use App\Models\Couple;
use App\Models\User;

class CouplePolicy
{
    public function view(User $user, Couple $couple): bool
    {
        return $couple->members()
            ->where('user_id', $user->id)
            ->exists();
    }
}
