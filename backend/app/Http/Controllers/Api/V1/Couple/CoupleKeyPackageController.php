<?php

namespace App\Http\Controllers\Api\V1\Couple;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Couple\StoreCoupleKeyPackageRequest;
use App\Http\Resources\Api\V1\Couple\CoupleKeyPackageResource;
use App\Http\Responses\ApiResponse;
use App\Services\CoupleKeyPackageService;
use Illuminate\Http\JsonResponse;

class CoupleKeyPackageController extends Controller
{
    public function __construct(
        private readonly CoupleKeyPackageService $service,
    ) {}

    public function index(
        \Illuminate\Http\Request $request,
    ): JsonResponse {
        $packages = $this->service->listForUser(
            $request->user(),
        );

        return ApiResponse::success(
            'Couple key packages retrieved successfully.',
            [
                'packages' => CoupleKeyPackageResource::collection(
                    $packages,
                ),
            ],
        );
    }

    public function store(
        StoreCoupleKeyPackageRequest $request,
    ): JsonResponse {
        $package = $this->service->create(
            $request->user(),
            $request->validated(),
        );

        return ApiResponse::success(
            'Couple key package created successfully.',
            [
                'package' => new CoupleKeyPackageResource($package),
            ],
        );
    }
}
