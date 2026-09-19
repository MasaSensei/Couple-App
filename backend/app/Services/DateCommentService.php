<?php

namespace App\Services;

use App\Models\Date;
use App\Models\DateComment;
use App\Models\User;
use DomainException;
use Illuminate\Database\Eloquent\Collection;

class DateCommentService
{
    public function getForDate(
        User $user,
        Date $date,
    ): Collection {
        $this->ensureMember($user, $date);

        return $date->comments()
            ->with('user')
            ->orderBy('created_at')
            ->get();
    }

    public function create(
        User $user,
        Date $date,
        string $content,
    ): DateComment {
        $this->ensureMember($user, $date);

        return $date->comments()->create([
            'user_id' => $user->id,
            'content' => $content,
        ])->load('user');
    }

    private function ensureMember(
        User $user,
        Date $date,
    ): void {
        $isMember = $date->couple
            ->members()
            ->where('user_id', $user->id)
            ->exists();

        if (! $isMember) {
            throw new DomainException(
                'User is not a member of this couple.'
            );
        }
    }
}
