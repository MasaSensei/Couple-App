<?php

namespace App\Services;

use App\Models\Couple;
use App\Models\CoupleMember;
use App\Models\CoupleKeyPackage;
use App\Models\User;
use App\Models\UserDevice;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Facades\DB;

class CoupleKeyPackageService
{
    /**
     * Stores a Couple Key already encrypted on a client for one device.
     * The recipient may be any active device of either couple member,
     * so an authorized device can share the key with a partner or a new device.
     */
    public function create(
        User $user,
        array $data,
    ): CoupleKeyPackage {
        $couple = $this->coupleFor($user);

        return DB::transaction(function () use ($couple, $data) {
            // Serialize package creation per couple so two devices cannot
            // establish two different Couple Keys at the same time.
            Couple::query()->whereKey($couple->id)->lockForUpdate()->first();

            $device = UserDevice::query()
                ->whereKey($data['device_id'])
                ->whereIn('user_id', $couple->members()->select('user_id'))
                ->whereNull('revoked_at')
                ->first();

            abort_unless($device !== null, 404);

            $currentKeyId = $couple->keyPackages()->oldest('id')->value('key_id');

            // shortcut: one Couple Key per couple; key rotation needs an explicit endpoint later.
            abort_if(
                $currentKeyId !== null && $currentKeyId !== $data['key_id'],
                409,
                'This couple already uses a different encryption key.',
            );

            abort_if(
                $couple->keyPackages()
                    ->where('device_id', $device->id)
                    ->where('key_id', $data['key_id'])
                    ->exists(),
                409,
                'A key package already exists for this device.',
            );

            return $couple->keyPackages()->create([
                'device_id' => $device->id,
                'key_id' => $data['key_id'],
                'encryption_version' => $data['encryption_version'],
                'ephemeral_public_key' => $data['ephemeral_public_key'],
                'nonce' => $data['nonce'],
                'ciphertext' => $data['ciphertext'],
                'mac' => $data['mac'],
            ]);
        });
    }

    public function listForUser(
        User $user,
    ): Collection {
        return $this->coupleFor($user)
            ->keyPackages()
            ->whereNull('revoked_at')
            ->latest()
            ->get();
    }

    /**
     * Active devices of both couple members. Public keys only.
     */
    public function devicesForUser(
        User $user,
    ): Collection {
        return UserDevice::query()
            ->whereIn('user_id', $this->coupleFor($user)->members()->select('user_id'))
            ->whereNull('revoked_at')
            ->oldest('id')
            ->get();
    }

    private function coupleFor(User $user): Couple
    {
        $couple = CoupleMember::query()
            ->where('user_id', $user->id)
            ->first()?->couple;

        abort_unless($couple !== null, 422);

        return $couple;
    }
}
