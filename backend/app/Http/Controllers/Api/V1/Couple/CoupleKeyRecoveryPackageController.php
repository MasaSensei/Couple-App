<?php

namespace App\Http\Controllers\Api\V1\Couple;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Couple\StoreCoupleKeyRecoveryPackageRequest;
use App\Http\Responses\ApiResponse;
use App\Models\CoupleKeyRecoveryPackage;
use App\Models\CoupleMember;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Stores the user's Couple Key encrypted with their Recovery Key.
 * The server cannot open it: the Recovery Key stays with the user.
 */
class CoupleKeyRecoveryPackageController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $package = CoupleKeyRecoveryPackage::query()
            ->where('user_id', $request->user()->id)
            ->first();

        abort_unless($package !== null, 404);

        return ApiResponse::success(
            'Recovery package retrieved successfully.',
            ['package' => $this->toArray($package)],
        );
    }

    public function update(StoreCoupleKeyRecoveryPackageRequest $request): JsonResponse
    {
        $coupleId = CoupleMember::query()
            ->where('user_id', $request->user()->id)
            ->value('couple_id');

        abort_unless($coupleId !== null, 422);

        $package = CoupleKeyRecoveryPackage::updateOrCreate(
            ['user_id' => $request->user()->id],
            ['couple_id' => $coupleId, ...$request->validated()],
        );

        return ApiResponse::success(
            'Recovery package saved successfully.',
            ['package' => $this->toArray($package)],
        );
    }

    private function toArray(CoupleKeyRecoveryPackage $package): array
    {
        return [
            'key_id' => $package->key_id,
            'format_version' => $package->format_version,
            'nonce' => $package->nonce,
            'ciphertext' => $package->ciphertext,
            'mac' => $package->mac,
            'updated_at' => $package->updated_at?->toISOString(),
        ];
    }
}
