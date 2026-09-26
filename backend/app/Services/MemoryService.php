<?php

namespace App\Services;

use App\Models\Couple;
use App\Models\Memory;
use App\Models\User;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use RuntimeException;

class MemoryService
{
    public function getUserCouple(User $user): Couple
    {
        $couple = $user->coupleMemberships()
            ->with('couple')
            ->first()
            ?->couple;

        if ($couple === null) {
            throw new RuntimeException(
                'User does not belong to a couple.'
            );
        }

        return $couple;
    }

    public function list(User $user): Collection
    {
        $couple = $this->getUserCouple($user);

        return Memory::query()
            ->where('couple_id', $couple->id)
            ->orderByDesc('memory_date')
            ->orderByDesc('created_at')
            ->get();
    }

    public function create(
        User $user,
        array $data,
    ): Memory {
        $couple = $this->getUserCouple($user);

        $this->validateDateBelongsToCouple(
            $data['date_id'] ?? null,
            $couple->id,
        );

        return DB::transaction(function () use (
            $user,
            $couple,
            $data,
        ): Memory {
            return Memory::create([
                'couple_id' => $couple->id,
                'created_by' => $user->id,
                'date_id' => $data['date_id'] ?? null,
                'title' => $data['title'],
                'description' => $data['description'] ?? null,
                'memory_date' => $data['memory_date'],
                'location_name' => $data['location_name'] ?? null,
                'location_address' => $data['location_address'] ?? null,
                'latitude' => $data['latitude'] ?? null,
                'longitude' => $data['longitude'] ?? null,
            ]);
        });
    }

    public function update(
        Memory $memory,
        array $data,
    ): Memory {
        $this->validateDateBelongsToCouple(
            $data['date_id'] ?? null,
            $memory->couple_id,
        );

        $memory->update($data);

        return $memory->refresh();
    }

    public function delete(Memory $memory): void
    {
        $memory->delete();
    }

    private function validateDateBelongsToCouple(
        ?int $dateId,
        int $coupleId,
    ): void {
        if ($dateId === null) {
            return;
        }

        $exists = \App\Models\Date::query()
            ->where('id', $dateId)
            ->where('couple_id', $coupleId)
            ->exists();

        if (! $exists) {
            throw new RuntimeException(
                'Date does not belong to this couple.'
            );
        }
    }

    public function timeline(
        User $user,
        int $perPage = 20,
    ): LengthAwarePaginator {
        $couple = $this->getUserCouple($user);

        return Memory::query()
            ->where('couple_id', $couple->id)
            ->orderByDesc('memory_date')
            ->orderByDesc('created_at')
            ->paginate($perPage);
    }
}
