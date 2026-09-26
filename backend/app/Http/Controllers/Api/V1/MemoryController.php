<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Memory\CreateMemoryRequest;
use App\Http\Requests\Api\V1\Memory\UpdateMemoryRequest;
use App\Http\Resources\Api\V1\MemoryResource;
use App\Http\Responses\ApiResponse;
use App\Models\Memory;
use App\Services\MemoryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use RuntimeException;

class MemoryController extends Controller
{
    public function __construct(
        private readonly MemoryService $memoryService,
    ) {}

    public function index(Request $request): JsonResponse
    {
        try {
            $memories = $this->memoryService->list(
                $request->user()
            );

            return ApiResponse::success(
                'Memories retrieved successfully.',
                [
                    'memories' => MemoryResource::collection(
                        $memories
                    ),
                ],
            );
        } catch (RuntimeException $exception) {
            return ApiResponse::error(
                $exception->getMessage(),
                status: 404,
            );
        }
    }

    public function store(
        CreateMemoryRequest $request,
    ): JsonResponse {
        try {
            $memory = $this->memoryService->create(
                $request->user(),
                $request->validated(),
            );

            return ApiResponse::success(
                'Memory created successfully.',
                [
                    'memory' => new MemoryResource($memory),
                ],
                201,
            );
        } catch (RuntimeException $exception) {
            return ApiResponse::error(
                $exception->getMessage(),
                status: 422,
            );
        }
    }

    public function show(
        Memory $memory,
    ): JsonResponse {
        Gate::authorize('view', $memory);

        return ApiResponse::success(
            'Memory retrieved successfully.',
            [
                'memory' => new MemoryResource($memory),
            ],
        );
    }

    public function update(
        UpdateMemoryRequest $request,
        Memory $memory,
    ): JsonResponse {
        Gate::authorize('update', $memory);

        try {
            $memory = $this->memoryService->update(
                $memory,
                $request->validated(),
            );

            return ApiResponse::success(
                'Memory updated successfully.',
                [
                    'memory' => new MemoryResource($memory),
                ],
            );
        } catch (RuntimeException $exception) {
            return ApiResponse::error(
                $exception->getMessage(),
                status: 422,
            );
        }
    }

    public function destroy(
        Memory $memory,
    ): JsonResponse {
        Gate::authorize('delete', $memory);

        $this->memoryService->delete($memory);

        return ApiResponse::success(
            'Memory deleted successfully.',
        );
    }

    public function timeline(
        Request $request,
    ): JsonResponse {
        $perPage = min(
            max(
                (int) $request->integer('per_page', 20),
                1,
            ),
            50,
        );

        $memories = $this->memoryService->timeline(
            $request->user(),
            $perPage,
        );

        return ApiResponse::success(
            'Memory timeline retrieved successfully.',
            [
                'memories' =>
                MemoryResource::collection(
                    $memories,
                ),
                'pagination' => [
                    'current_page' =>
                    $memories->currentPage(),

                    'last_page' =>
                    $memories->lastPage(),

                    'per_page' =>
                    $memories->perPage(),

                    'total' =>
                    $memories->total(),
                ],
            ],
        );
    }
}
