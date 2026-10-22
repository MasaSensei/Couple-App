<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Memory\CreateMemoryPhotoUploadRequest;
use App\Http\Resources\Api\V1\Memory\MemoryPhotoResource;
use App\Http\Responses\ApiResponse;
use App\Models\Memory;
use App\Models\MemoryPhoto;
use App\Services\Memory\MemoryPhotoService;
use App\Services\Storage\PhotoStorage;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Gate;
use RuntimeException;
use Symfony\Component\HttpFoundation\Response;
use App\Http\Requests\Api\V1\Memory\UploadMemoryPhotoRequest;
use App\Http\Requests\Api\V1\Memory\UpdateMemoryPhotoEncryptionRequest;

class MemoryPhotoController extends Controller
{
    public function __construct(
        private readonly MemoryPhotoService $photoService,
        private readonly PhotoStorage $photoStorage,
    ) {}

    public function index(Memory $memory): JsonResponse
    {
        Gate::authorize('view', $memory);

        $photos = $this->photoService->listForMemory($memory);

        return ApiResponse::success(
            'Memory photos retrieved successfully.',
            [
                'photos' => MemoryPhotoResource::collection($photos),
            ],
        );
    }

    public function upload(
        CreateMemoryPhotoUploadRequest $request,
        Memory $memory,
    ): JsonResponse {
        Gate::authorize('view', $memory);

        try {
            $result = $this->photoService
                ->createUploadSession(
                    $request->user(),
                    $memory,
                    $request->validated(),
                );

            return ApiResponse::success(
                'Photo upload session created successfully.',
                [
                    'photo' => new MemoryPhotoResource(
                        $result['photo'],
                    ),
                    'upload' => $result['upload'],
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


    public function updateEncryption(
        UpdateMemoryPhotoEncryptionRequest $request,
        MemoryPhoto $photo,
    ): JsonResponse {
        Gate::authorize('upload', $photo);

        try {
            $photo = $this->photoService->updateEncryptionMetadata(
                $photo,
                $request->validated(),
            );

            return ApiResponse::success(
                'Photo encryption metadata updated successfully.',
                [
                    'photo' => new MemoryPhotoResource($photo),
                ],
            );
        } catch (RuntimeException $exception) {
            return ApiResponse::error(
                $exception->getMessage(),
                status: 422,
            );
        }
    }


    public function complete(
        MemoryPhoto $photo,
    ): JsonResponse {
        Gate::authorize('complete', $photo);

        try {
            $photo = $this->photoService
                ->complete($photo);

            return ApiResponse::success(
                'Photo upload completed successfully.',
                [
                    'photo' => new MemoryPhotoResource(
                        $photo,
                    ),
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
        MemoryPhoto $photo,
    ): JsonResponse {
        Gate::authorize('delete', $photo);

        try {
            $this->photoService->delete($photo);

            return ApiResponse::success(
                'Photo deleted successfully.',
            );
        } catch (RuntimeException $exception) {
            return ApiResponse::error(
                $exception->getMessage(),
                status: 422,
            );
        }
    }


    public function content(MemoryPhoto $photo): Response
    {
        Gate::authorize('view', $photo);

        abort_unless($photo->status === 'verified', 404);

        $path = $this->photoStorage->getObject($photo->storage_key);

        // Always ciphertext: never let a client render it as an image.
        return response()->file($path, [
            'Content-Type' => 'application/octet-stream',
            'Cache-Control' => 'private, no-store',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }


    public function uploadBinary(
        UploadMemoryPhotoRequest $request,
        MemoryPhoto $photo,
    ): JsonResponse {
        Gate::authorize('upload', $photo);

        try {
            $photo = $this->photoService->upload(
                $request->user(),
                $photo,
                $request->file('photo'),
            );

            return ApiResponse::success(
                'Photo uploaded successfully.',
                [
                    'photo' => new MemoryPhotoResource($photo),
                ],
            );
        } catch (RuntimeException $exception) {
            return ApiResponse::error(
                $exception->getMessage(),
                status: 422,
            );
        }
    }
}
