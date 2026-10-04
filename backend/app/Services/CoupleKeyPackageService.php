<?php

namespace App\Services;

use App\Models\CoupleMember;
use App\Models\CoupleKeyPackage;
use App\Models\User;
use App\Models\UserDevice;
use Illuminate\Support\Facades\DB;

class CoupleKeyPackageService
{
    public function create(
        User $user,
        array $data,
    ): CoupleKeyPackage {
        return DB::transaction(function () use ($user, $data) {
            $device = UserDevice::query()
                ->whereKey($data['device_id'])
                ->where('user_id', $user->id)
                ->whereNull('revoked_at')
                ->first();

            abort_unless($device !== null, 404);

            $couple = CoupleMember::query()
                ->where('user_id', $user->id)
                ->first()?->couple;

            abort_unless($couple !== null, 422);

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
    ): \Illuminate\Database\Eloquent\Collection {
        $couple = CoupleMember::query()
            ->where('user_id', $user->id)
            ->first()?->couple;

        abort_unless($couple !== null, 422);

        return $couple->keyPackages()
            ->whereNull('revoked_at')
            ->latest()
            ->get();
    }
}
