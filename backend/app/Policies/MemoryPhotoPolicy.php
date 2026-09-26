<?php

namespace App\Policies;

use App\Models\MemoryPhoto;
use App\Models\User;

class MemoryPhotoPolicy
{
    public function view(
        User $user,
        MemoryPhoto $photo,
    ): bool {
        if ($photo->trashed()) {
            return false;
        }

        if ($photo->status !== 'verified') {
            return false;
        }

        return $photo->memory
            ->couple
            ->members()
            ->where('user_id', $user->id)
            ->exists();
    }

    public function delete(
        User $user,
        MemoryPhoto $photo,
    ): bool {
        return $this->view($user, $photo);
    }
}
