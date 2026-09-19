<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Resources\Api\V1\CoupleInvitationResource;
use App\Http\Requests\Api\V1\Couple\CreateCoupleInvitationRequest;
use App\Services\CoupleInvitationService;
use App\Models\CoupleInvitation;
use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\CoupleResource;
use App\Http\Requests\Api\V1\Couple\JoinCoupleRequest;
use App\Http\Responses\ApiResponse;
use App\Services\CoupleService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class CoupleController extends Controller
{
    public function __construct(
        private readonly CoupleService $coupleService,
        private readonly CoupleInvitationService $coupleInvitationService,
    ) {}

    public function store(Request $request): JsonResponse
    {
        $couple = $this->coupleService->createForUser(
            $request->user()
        );

        return ApiResponse::success(
            'Couple created successfully.',
            [
                'couple' => new CoupleResource($couple),
            ],
            201,
        );
    }

    public function show(Request $request): JsonResponse
    {
        $couple = $this->coupleService->getForUser(
            $request->user()
        );

        if (! $couple) {
            return ApiResponse::error(
                'User does not belong to a couple.',
                null,
                404,
            );
        }

        return ApiResponse::success(
            'Couple retrieved successfully.',
            [
                'couple' => new CoupleResource($couple),
            ],
        );
    }

    public function join(JoinCoupleRequest $request): JsonResponse
    {
        $couple = $this->coupleService->joinByInviteCode(
            $request->user(),
            $request->validated('invite_code')
        );

        return ApiResponse::success(
            'Successfully joined the couple.',
            [
                'couple' => new CoupleResource($couple),
            ],
        );
    }

    public function showById(int $coupleId): JsonResponse
    {
        $couple = $this->coupleService->findById($coupleId);

        if (! $couple) {
            return ApiResponse::error(
                'Couple not found.',
                null,
                404,
            );
        }

        Gate::authorize('view', $couple);

        return ApiResponse::success(
            'Couple retrieved successfully.',
            [
                'couple' => new CoupleResource($couple),
            ],
        );
    }

    public function createInvitation(
        CreateCoupleInvitationRequest $request,
    ): JsonResponse {
        $user = $request->user();

        $couple = $this->coupleService->getForUser($user);

        if (! $couple) {
            return ApiResponse::error(
                'User does not belong to a couple.',
                null,
                404,
            );
        }

        Gate::authorize('createInvitation', $couple);

        $invitation = $this->coupleInvitationService->create(
            $user,
            $couple,
        );

        return ApiResponse::success(
            'Couple invitation created successfully.',
            [
                'invitation' => [
                    'id' => $invitation->id,
                    'token' => $invitation->token,
                    'status' => $invitation->status,
                    'expires_at' => $invitation->expires_at?->toISOString(),
                ],
            ],
            201,
        );
    }

    public function showInvitation(
        string $token,
    ): JsonResponse {
        $invitation = $this->coupleInvitationService
            ->findByToken($token);

        return ApiResponse::success(
            'Invitation retrieved successfully.',
            [
                'invitation' => new CoupleInvitationResource(
                    $invitation
                ),
            ],
        );
    }

    public function acceptInvitation(
        Request $request,
        string $token,
    ): JsonResponse {
        $user = $request->user();

        $couple = $this->coupleInvitationService->accept(
            $user,
            $token,
        );

        return ApiResponse::success(
            'Invitation accepted successfully.',
            [
                'couple' => new CoupleResource($couple),
            ],
        );
    }
}
