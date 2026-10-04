<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Devices\RegisterDeviceRequest;
use App\Http\Responses\ApiResponse;
use App\Models\UserDevice;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Http\Resources\Api\V1\Devices\DeviceResource;

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
        $device = $request->user()
            ->devices()
            ->updateOrCreate(
                [
                    'device_identifier' => $request->string(
                        'device_identifier',
                    )->toString(),
                ],
                [
                    'device_name' => $request->input('device_name'),
                    'platform' => $request->string('platform')->toString(),
                    'public_key' => $request->string('public_key')->toString(),
                    'last_seen_at' => now(),
                    'revoked_at' => null,
                ],
            );

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

        $device->update([
            'revoked_at' => now(),
        ]);

        return ApiResponse::success(
            'Device revoked successfully.',
        );
    }
}
