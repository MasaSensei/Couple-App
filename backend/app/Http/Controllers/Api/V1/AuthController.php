<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Auth\LoginRequest;
use App\Http\Requests\Api\V1\Auth\RegisterRequest;
use App\Http\Resources\Api\V1\UserResource;
use App\Http\Requests\Api\V1\User\UpdateProfileRequest;
use App\Services\UserService;
use App\Services\AuthService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Http\Responses\ApiResponse;

class AuthController extends Controller
{
    public function __construct(
        private readonly AuthService $authService,
        private readonly UserService $userService,
    ) {}

    public function register(RegisterRequest $request): JsonResponse
    {
        $result = $this->authService->register(
            $request->validated()
        );

        return ApiResponse::success(
            'Registration successful.',
            [
                'user' => new UserResource($result['user']),
                'token' => $result['token'],
            ],
            201,
        );
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $result = $this->authService->login(
            $request->validated()
        );

        return ApiResponse::success(
            'Login successful.',
            [
                'user' => new UserResource($result['user']),
                'token' => $result['token'],
            ],
        );
    }

    public function logout(Request $request): JsonResponse
    {
        $this->authService->logout(
            $request->user()
        );

        return ApiResponse::success(
            'Logged out successfully.',
            null,
        );
    }

    public function me(Request $request): JsonResponse
    {
        return ApiResponse::success(
            'User retrieved successfully.',
            [
                'user' => new UserResource($request->user()),
            ],
        );
    }

    public function updateProfile(UpdateProfileRequest $request): JsonResponse
    {
        $user = $this->userService->updateProfile(
            $request->user(),
            $request->validated()
        );

        return ApiResponse::success(
            'Profile updated successfully.',
            [
                'user' => new UserResource($user),
            ],
        );
    }
}
