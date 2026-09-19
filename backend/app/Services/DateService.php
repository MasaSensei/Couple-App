<?php

namespace App\Services;

use App\Models\Couple;
use App\Models\Date;
use App\Models\User;
use DomainException;
use Illuminate\Database\Eloquent\Collection;

class DateService
{
    public function getForCouple(
        Couple $couple,
    ): Collection {
        return Date::query()
            ->where('couple_id', $couple->id)
            ->orderBy('scheduled_at')
            ->get();
    }

    public function getById(
        Couple $couple,
        int $dateId,
    ): Date {
        $date = Date::query()
            ->where('couple_id', $couple->id)
            ->whereKey($dateId)
            ->first();

        if (! $date) {
            throw new DomainException(
                'Date not found.'
            );
        }

        return $date;
    }

    public function create(
        User $user,
        Couple $couple,
        array $data,
    ): Date {
        $this->ensureMember($user, $couple);

        return $couple->dates()->create([
            'created_by' => $user->id,
            'title' => $data['title'],
            'description' => $data['description'] ?? null,
            'location' => $data['location'] ?? null,
            'scheduled_at' => $data['scheduled_at'],
            'status' => 'planned',
        ]);
    }

    public function update(
        User $user,
        Couple $couple,
        Date $date,
        array $data,
    ): Date {
        $this->ensureMember($user, $couple);
        $this->ensureBelongsToCouple($date, $couple);

        $date->update($data);

        return $date->refresh();
    }

    public function complete(
        User $user,
        Couple $couple,
        Date $date,
    ): Date {
        $this->ensureMember($user, $couple);
        $this->ensureBelongsToCouple($date, $couple);

        if ($date->status === 'cancelled') {
            throw new DomainException(
                'Cancelled date cannot be completed.'
            );
        }

        $date->update([
            'status' => 'completed',
            'completed_at' => now(),
        ]);

        return $date->refresh();
    }

    public function cancel(
        User $user,
        Couple $couple,
        Date $date,
    ): Date {
        $this->ensureMember($user, $couple);
        $this->ensureBelongsToCouple($date, $couple);

        if ($date->status === 'completed') {
            throw new DomainException(
                'Completed date cannot be cancelled.'
            );
        }

        $date->update([
            'status' => 'cancelled',
            'completed_at' => null,
        ]);

        return $date->refresh();
    }

    private function ensureMember(
        User $user,
        Couple $couple,
    ): void {
        $isMember = $couple->members()
            ->where('user_id', $user->id)
            ->exists();

        if (! $isMember) {
            throw new DomainException(
                'User is not a member of this couple.'
            );
        }
    }

    private function ensureBelongsToCouple(
        Date $date,
        Couple $couple,
    ): void {
        if ($date->couple_id !== $couple->id) {
            throw new DomainException(
                'Date does not belong to this couple.'
            );
        }
    }
}
