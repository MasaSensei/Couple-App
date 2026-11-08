<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Devices\RegisterDeviceRequest;
use App\Http\Resources\Api\V1\Devices\DeviceResource;
use App\Http\Responses\ApiResponse;
use App\Models\UserDevice;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\PersonalAccessToken;

class DeviceController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $devices = $request->user()
            ->devices()
            ->latest()
            ->get();

        return ApiResponse::success(
            'Devices retrieved successfully.',
            [
                'devices' => DeviceResource::collection($devices),
            ],
        );
    }

    public function store(RegisterDeviceRequest $request): JsonResponse
    {
        $user = $request->user();
        $identifier = $request->string('device_identifier')->toString();
        $publicKey = $request->string('public_key')->toString();

        $existing = $user->devices()
            ->where('device_identifier', $identifier)
            ->first();

        // A revoked device stays revoked. The app must register as a new device.
        if ($existing?->revoked_at !== null) {
            return ApiResponse::error(
                'This device has been revoked.',
                status: 403,
            );
        }

        $device = DB::transaction(function () use ($request, $user, $identifier, $publicKey, $existing): UserDevice {
            // Key packages wrapped for an old public key can no longer be opened.
            if ($existing !== null && $existing->public_key !== $publicKey) {
                $existing->coupleKeyPackages()
                    ->whereNull('revoked_at')
                    ->update(['revoked_at' => now()]);
            }

            $device = $user->devices()->updateOrCreate(
                ['device_identifier' => $identifier],
                [
                    'device_name' => $request->input('device_name'),
                    'platform' => $request->string('platform')->toString(),
                    'public_key' => $publicKey,
                    'last_seen_at' => now(),
                ],
            );

            $token = $user->currentAccessToken();

            if ($token instanceof PersonalAccessToken) {
                $token->forceFill(['user_device_id' => $device->id])->save();
            }

            return $device;
        });

        return ApiResponse::success(
            'Device registered successfully.',
            [
                'device' => new DeviceResource($device),
            ],
        );
    }

    public function destroy(
        Request $request,
        UserDevice $device,
    ): JsonResponse {
        abort_unless(
            $device->user_id === $request->user()->id,
            404,
        );

        DB::transaction(function () use ($device): void {
            $revokedAt = now();

            $device->update([
                'revoked_at' => $revokedAt,
            ]);

            $device->coupleKeyPackages()
                ->whereNull('revoked_at')
                ->update([
                    'revoked_at' => $revokedAt,
                ]);

            // Sign the revoked device out so it can no longer call the API.
            PersonalAccessToken::query()
                ->where('user_device_id', $device->id)
                ->delete();
        });

        return ApiResponse::success(
            'Device revoked successfully.',
        );
    }
}
