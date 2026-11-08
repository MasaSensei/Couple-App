<?php

namespace App\Services;

use App\Models\Couple;
use App\Models\Date;
use App\Models\Memory;
use App\Models\PhotoStorageAudit;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;
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
            ->withTimelineSummary()
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

    /** Soft delete; its photos go to the trash with the same retention as a single photo delete. */
    public function delete(Memory $memory, ?User $user = null): void
    {
        DB::transaction(function () use ($memory, $user): void {
            $actor = $user ? "user:{$user->id}" : 'system';

            $memory->photos()->get()->each(function ($photo) use ($actor): void {
                $photo->delete();
                PhotoStorageAudit::record($photo->id, 'trash', 'succeeded', $actor, 'Memory deleted.');
            });

            $memory->delete();
        });
    }

    private function validateDateBelongsToCouple(
        ?int $dateId,
        int $coupleId,
    ): void {
        if ($dateId === null) {
            return;
        }

        $exists = Date::query()
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
            ->withTimelineSummary()
            ->paginate($perPage);
    }
}
