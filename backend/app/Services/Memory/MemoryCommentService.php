<?php

namespace App\Services\Memory;

use App\Models\Memory;
use App\Models\MemoryComment;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;

class MemoryCommentService
{
    public function list(
        Memory $memory,
    ): Collection {
        return $memory->comments()
            ->with('user')
            ->latest('created_at')
            ->get();
    }

    public function create(
        User $user,
        Memory $memory,
        string $body,
    ): MemoryComment {
        return $memory->comments()->create([
            'user_id' => $user->id,
            'body' => $body,
        ]);
    }

    public function update(
        MemoryComment $comment,
        string $body,
    ): MemoryComment {
        $comment->update([
            'body' => $body,
        ]);

        return $comment->refresh();
    }

    public function delete(
        MemoryComment $comment,
    ): void {
        $comment->delete();
    }
}
