<?php

namespace App\Services;

use App\Models\Couple;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CoupleService
{
    public function createForUser(User $user): Couple
    {
        if ($this->getForUser($user)) {
            throw new \DomainException('User already belongs to a couple.');
        }

        return DB::transaction(function () use ($user) {
            $couple = Couple::create([
                'invite_code' => $this->generateInviteCode(),
            ]);

            $couple->members()->create([
                'user_id' => $user->id,
            ]);

            return $couple->load('members.user');
        });
    }

    public function getForUser(User $user): ?Couple
    {
        return Couple::query()
            ->whereHas('members', function ($query) use ($user) {
                $query->where('user_id', $user->id);
            })
            ->with('members.user')
            ->first();
    }

    private function generateInviteCode(): string
    {
        do {
            $code = Str::upper(Str::random(8));
        } while (Couple::where('invite_code', $code)->exists());

        return $code;
    }

    public function joinByInviteCode(User $user, string $inviteCode): Couple
    {
        if ($this->getForUser($user)) {
            throw new \DomainException(
                'User already belongs to a couple.'
            );
        }

        return DB::transaction(function () use ($user, $inviteCode) {
            $couple = Couple::query()
                ->where('invite_code', $inviteCode)
                ->lockForUpdate()
                ->first();

            if (! $couple) {
                throw new \DomainException(
                    'Invalid invite code.'
                );
            }

            if ($couple->members()->count() >= 2) {
                throw new \DomainException(
                    'This couple already has two members.'
                );
            }

            $couple->members()->create([
                'user_id' => $user->id,
            ]);

            return $couple->load('members.user');
        });
    }

    public function findById(int $coupleId): ?Couple
    {
        return Couple::query()
            ->with('members.user')
            ->find($coupleId);
    }
}
