<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Auth\LoginRequest;
use App\Http\Requests\Api\V1\Auth\RegisterRequest;
use App\Http\Requests\Api\V1\User\UpdateProfileRequest;
use App\Http\Resources\Api\V1\UserResource;
use App\Http\Responses\ApiResponse;
use App\Services\AuthService;
use App\Services\UserService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Laravel\Sanctum\PersonalAccessToken;

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
                'token_expires_at' => $result['token_expires_at'],
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
                'token_expires_at' => $result['token_expires_at'],
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

    public function refresh(Request $request): JsonResponse
    {
        $current = $request->user()->currentAccessToken();

        abort_unless($current instanceof PersonalAccessToken, 400, 'Only API tokens can be refreshed.');

        $result = $this->authService->refresh($request->user(), $current);

        return ApiResponse::success('Token refreshed.', $result);
    }

    public function logoutAll(Request $request): JsonResponse
    {
        $count = $this->authService->logoutAll($request->user());

        return ApiResponse::success('Signed out of all sessions.', ['revoked' => $count]);
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
