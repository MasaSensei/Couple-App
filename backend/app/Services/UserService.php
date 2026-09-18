<?php

namespace App\Services;

use App\Models\User;

class UserService
{
    public function updateProfile(User $user, array $data): User
    {
        $user->update($data);

        return $user->fresh();
    }
}
