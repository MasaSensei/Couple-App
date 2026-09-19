<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Date\CreateDateRequest;
use App\Http\Requests\Api\V1\Date\UpdateDateRequest;
use App\Http\Resources\Api\V1\DateResource;
use App\Http\Responses\ApiResponse;
use App\Services\DateService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DateController extends Controller
{
    public function __construct(
        private readonly DateService $dateService,
    ) {}

    public function index(
        Request $request,
    ): JsonResponse {
        $user = $request->user();

        $couple = $user
            ->coupleMemberships()
            ->with('couple')
            ->first()
            ?->couple;

        if (! $couple) {
            return ApiResponse::error(
                'User does not belong to a couple.',
                null,
                404,
            );
        }

        $dates = $this->dateService->getForCouple(
            $couple,
        );

        return ApiResponse::success(
            'Dates retrieved successfully.',
            [
                'dates' => DateResource::collection($dates),
            ],
        );
    }

    public function store(
        CreateDateRequest $request,
    ): JsonResponse {
        $user = $request->user();

        $couple = $user
            ->coupleMemberships()
            ->with('couple')
            ->first()
            ?->couple;

        if (! $couple) {
            return ApiResponse::error(
                'User does not belong to a couple.',
                null,
                404,
            );
        }

        $date = $this->dateService->create(
            $user,
            $couple,
            $request->validated(),
        );

        return ApiResponse::success(
            'Date created successfully.',
            [
                'date' => new DateResource($date),
            ],
            201,
        );
    }

    public function show(
        Request $request,
        int $dateId,
    ): JsonResponse {
        $user = $request->user();

        $couple = $user
            ->coupleMemberships()
            ->with('couple')
            ->first()
            ?->couple;

        if (! $couple) {
            return ApiResponse::error(
                'User does not belong to a couple.',
                null,
                404,
            );
        }

        $date = $this->dateService->getById(
            $couple,
            $dateId,
        );

        return ApiResponse::success(
            'Date retrieved successfully.',
            [
                'date' => new DateResource($date),
            ],
        );
    }

    public function update(
        UpdateDateRequest $request,
        int $dateId,
    ): JsonResponse {
        $user = $request->user();

        $couple = $user
            ->coupleMemberships()
            ->with('couple')
            ->first()
            ?->couple;

        if (! $couple) {
            return ApiResponse::error(
                'User does not belong to a couple.',
                null,
                404,
            );
        }

        $date = $this->dateService->getById(
            $couple,
            $dateId,
        );

        $date = $this->dateService->update(
            $user,
            $couple,
            $date,
            $request->validated(),
        );

        return ApiResponse::success(
            'Date updated successfully.',
            [
                'date' => new DateResource($date),
            ],
        );
    }

    public function complete(
        Request $request,
        int $dateId,
    ): JsonResponse {
        $user = $request->user();

        $couple = $user
            ->coupleMemberships()
            ->with('couple')
            ->first()
            ?->couple;

        if (! $couple) {
            return ApiResponse::error(
                'User does not belong to a couple.',
                null,
                404,
            );
        }

        $date = $this->dateService->getById(
            $couple,
            $dateId,
        );

        $date = $this->dateService->complete(
            $user,
            $couple,
            $date,
        );

        return ApiResponse::success(
            'Date completed successfully.',
            [
                'date' => new DateResource($date),
            ],
        );
    }

    public function cancel(
        Request $request,
        int $dateId,
    ): JsonResponse {
        $user = $request->user();

        $couple = $user
            ->coupleMemberships()
            ->with('couple')
            ->first()
            ?->couple;

        if (! $couple) {
            return ApiResponse::error(
                'User does not belong to a couple.',
                null,
                404,
            );
        }

        $date = $this->dateService->getById(
            $couple,
            $dateId,
        );

        $date = $this->dateService->cancel(
            $user,
            $couple,
            $date,
        );

        return ApiResponse::success(
            'Date cancelled successfully.',
            [
                'date' => new DateResource($date),
            ],
        );
    }
}
