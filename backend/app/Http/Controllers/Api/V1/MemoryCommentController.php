<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Memory\CreateMemoryCommentRequest;
use App\Http\Requests\Api\V1\Memory\UpdateMemoryCommentRequest;
use App\Http\Resources\Api\V1\Memory\MemoryCommentResource;
use App\Http\Responses\ApiResponse;
use App\Models\Memory;
use App\Models\MemoryComment;
use App\Services\Memory\MemoryCommentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Gate;

class MemoryCommentController extends Controller
{
    public function __construct(
        private readonly MemoryCommentService $commentService,
    ) {}

    public function index(
        Memory $memory,
    ): JsonResponse {
        Gate::authorize('view', $memory);

        $comments = $this->commentService->list(
            $memory,
        );

        return ApiResponse::success(
            'Memory comments retrieved successfully.',
            [
                'comments' =>
                MemoryCommentResource::collection(
                    $comments,
                ),
            ],
        );
    }

    public function store(
        CreateMemoryCommentRequest $request,
        Memory $memory,
    ): JsonResponse {
        Gate::authorize('view', $memory);

        $comment = $this->commentService->create(
            $request->user(),
            $memory,
            $request->validated('body'),
        );

        $comment->load('user');

        return ApiResponse::success(
            'Memory comment created successfully.',
            [
                'comment' =>
                new MemoryCommentResource($comment),
            ],
            201,
        );
    }

    public function update(
        UpdateMemoryCommentRequest $request,
        MemoryComment $comment,
    ): JsonResponse {
        Gate::authorize('update', $comment);

        $comment = $this->commentService->update(
            $comment,
            $request->validated('body'),
        );

        $comment->load('user');

        return ApiResponse::success(
            'Memory comment updated successfully.',
            [
                'comment' =>
                new MemoryCommentResource($comment),
            ],
        );
    }

    public function destroy(
        MemoryComment $comment,
    ): JsonResponse {
        Gate::authorize('delete', $comment);

        $this->commentService->delete(
            $comment,
        );

        return ApiResponse::success(
            'Memory comment deleted successfully.',
        );
    }
}
