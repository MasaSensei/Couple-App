<?php

namespace App\Http\Controllers\Api\V1\Billing;

use App\Http\Controllers\Controller;
use App\Http\Responses\ApiResponse;
use App\Services\Billing\Providers\InvalidWebhookSignature;
use App\Services\Billing\WebhookReceiver;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Unauthenticated by design: trust comes from the provider's signature only. */
class WebhookController extends Controller
{
    public function __invoke(string $provider, Request $request, WebhookReceiver $receiver): JsonResponse
    {
        try {
            $result = $receiver->receive($provider, $request);
        } catch (InvalidWebhookSignature) {
            return ApiResponse::error('Invalid signature.', status: 401);
        }

        // 200 for duplicates too, so the provider stops redelivering.
        return ApiResponse::success($result['status'] === 'duplicate' ? 'Already received.' : 'Accepted.', ['status' => $result['status']]);
    }
}
