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

    public function upload(
        User $user,
        MemoryPhoto $photo,
    ): bool {
        if ($photo->trashed()) {
            return false;
        }

        if (! in_array($photo->status, ['pending', 'uploading'], true)) {
            return false;
        }

        return $photo->memory
            ->couple
            ->members()
            ->where('user_id', $user->id)
            ->exists();
    }

    public function complete(
        User $user,
        MemoryPhoto $photo,
    ): bool {
        if ($photo->trashed()) {
            return false;
        }

        if ($photo->status !== 'uploading') {
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

    /**
     * Any member of the couple may restore from the trash, but only while the
     * memory itself still exists and the retention period has not ended.
     */
    public function restore(
        User $user,
        MemoryPhoto $photo,
    ): bool {
        if (! $photo->isRestorable()) {
            return false;
        }

        // `memory` is null when the memory itself is in the trash.
        $memory = $photo->memory;

        return $memory !== null
            && $memory->couple
                ->members()
                ->where('user_id', $user->id)
                ->exists();
    }
}
