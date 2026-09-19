<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Date\CreateDateCommentRequest;
use App\Http\Resources\Api\V1\DateCommentResource;
use App\Http\Responses\ApiResponse;
use App\Models\Date;
use App\Services\DateCommentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DateCommentController extends Controller
{
    public function __construct(
        private readonly DateCommentService $dateCommentService,
    ) {}

    public function index(
        Request $request,
        int $dateId,
    ): JsonResponse {
        $user = $request->user();

        $date = $user
            ->coupleMemberships()
            ->with('couple')
            ->first()
            ?->couple
            ?->dates()
            ->whereKey($dateId)
            ->first();

        if (! $date) {
            return ApiResponse::error(
                'Date not found.',
                null,
                404,
            );
        }

        $comments = $this->dateCommentService->getForDate(
            $user,
            $date,
        );

        return ApiResponse::success(
            'Date comments retrieved successfully.',
            [
                'comments' => DateCommentResource::collection(
                    $comments,
                ),
            ],
        );
    }

    public function store(
        CreateDateCommentRequest $request,
        int $dateId,
    ): JsonResponse {
        $user = $request->user();

        $date = $user
            ->coupleMemberships()
            ->with('couple')
            ->first()
            ?->couple
            ?->dates()
            ->whereKey($dateId)
            ->first();

        if (! $date) {
            return ApiResponse::error(
                'Date not found.',
                null,
                404,
            );
        }

        $comment = $this->dateCommentService->create(
            $user,
            $date,
            $request->validated()['content'],
        );

        return ApiResponse::success(
            'Date comment created successfully.',
            [
                'comment' => new DateCommentResource(
                    $comment,
                ),
            ],
            201,
        );
    }
}
