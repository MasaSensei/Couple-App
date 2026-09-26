<?php

namespace App\Policies;

use App\Models\MemoryComment;
use App\Models\User;

class MemoryCommentPolicy
{
    public function view(
        User $user,
        MemoryComment $comment,
    ): bool {
        return $comment->memory
            ->couple
            ->members()
            ->where('user_id', $user->id)
            ->exists();
    }

    public function create(
        User $user,
        MemoryComment $comment,
    ): bool {
        return $this->view(
            $user,
            $comment,
        );
    }

    public function update(
        User $user,
        MemoryComment $comment,
    ): bool {
        return $comment->user_id === $user->id
            && $this->view(
                $user,
                $comment,
            );
    }

    public function delete(
        User $user,
        MemoryComment $comment,
    ): bool {
        return $comment->user_id === $user->id
            && $this->view(
                $user,
                $comment,
            );
    }
}
