<?php

namespace App\Services;

use App\Models\Couple;
use App\Models\CoupleInvitation;
use App\Models\User;
use DomainException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CoupleInvitationService
{
    public function create(
        User $user,
        Couple $couple,
    ): CoupleInvitation {
        $isMember = $couple->members()
            ->where('user_id', $user->id)
            ->exists();

        if (! $isMember) {
            throw new DomainException(
                'User is not a member of this couple.'
            );
        }

        if ($couple->members()->count() >= 2) {
            throw new DomainException(
                'This couple already has two members.'
            );
        }

        return DB::transaction(function () use ($user, $couple) {
            $token = $this->generateToken();

            return $couple->invitations()->create([
                'invited_by' => $user->id,
                'token' => $token,
                'status' => 'pending',
                'expires_at' => now()->addDays(7),
            ]);
        });
    }

    public function findByToken(
        string $token,
    ): CoupleInvitation {
        $invitation = CoupleInvitation::query()
            ->with(['couple.members.user', 'invitedBy'])
            ->where('token', $token)
            ->first();

        if (! $invitation) {
            throw new DomainException(
                'Invalid invitation.'
            );
        }

        if ($invitation->status !== 'pending') {
            throw new DomainException(
                'This invitation is no longer active.'
            );
        }

        if ($invitation->expires_at->isPast()) {
            $invitation->update([
                'status' => 'expired',
            ]);

            throw new DomainException(
                'This invitation has expired.'
            );
        }

        return $invitation;
    }

    private function generateToken(): string
    {
        do {
            $token = Str::random(64);
        } while (
            CoupleInvitation::query()
            ->where('token', $token)
            ->exists()
        );

        return $token;
    }

    public function accept(
        User $user,
        string $token,
    ): Couple {
        $invitation = CoupleInvitation::query()
            ->where('token', $token)
            ->first();

        if (! $invitation) {
            throw new DomainException(
                'Invalid invitation.'
            );
        }

        if ($invitation->status !== 'pending') {
            throw new DomainException(
                'This invitation is no longer active.'
            );
        }

        if ($invitation->expires_at->isPast()) {
            $invitation->update([
                'status' => 'expired',
            ]);

            throw new DomainException(
                'This invitation has expired.'
            );
        }

        return DB::transaction(function () use ($user, $token) {
            $invitation = CoupleInvitation::query()
                ->where('token', $token)
                ->lockForUpdate()
                ->first();

            if (! $invitation) {
                throw new DomainException(
                    'Invalid invitation.'
                );
            }

            if ($invitation->status !== 'pending') {
                throw new DomainException(
                    'This invitation is no longer active.'
                );
            }

            if ($invitation->expires_at->isPast()) {
                $invitation->update([
                    'status' => 'expired',
                ]);

                throw new DomainException(
                    'This invitation has expired.'
                );
            }

            if ($user->coupleMemberships()->exists()) {
                throw new DomainException(
                    'User already belongs to a couple.'
                );
            }

            $couple = Couple::query()
                ->whereKey($invitation->couple_id)
                ->lockForUpdate()
                ->first();

            if (! $couple) {
                throw new DomainException(
                    'Couple no longer exists.'
                );
            }

            if ($couple->members()->count() >= 2) {
                throw new DomainException(
                    'This couple already has two members.'
                );
            }

            $alreadyMember = $couple->members()
                ->where('user_id', $user->id)
                ->exists();

            if ($alreadyMember) {
                throw new DomainException(
                    'User is already a member of this couple.'
                );
            }

            $couple->members()->create([
                'user_id' => $user->id,
            ]);

            $invitation->update([
                'status' => 'accepted',
                'accepted_at' => now(),
            ]);

            return $couple->load('members.user');
        });
    }
}
