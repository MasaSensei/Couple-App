<?php

namespace App\Http\Controllers\Api\V1\Billing;

use App\Http\Controllers\Controller;
use App\Http\Responses\ApiResponse;
use App\Services\Billing\Providers\MockStore;
use App\Services\Billing\Providers\PurchaseVerificationFailed;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Stand-in for the store's purchase sheet, so the Flutter purchase flow can
 * be exercised end to end in development. The route only exists when the
 * mock provider is enabled (never in production). It grants nothing by
 * itself: the app must still call /couple/subscription/verify.
 */
class MockStoreController extends Controller
{
    public function purchase(Request $request, MockStore $store): JsonResponse
    {
        $data = $request->validate([
            'product_id' => ['required', 'string', 'max:255'],
            'account_token' => ['required', 'uuid'],
            'replaces_subscription_id' => ['nullable', 'string', 'max:255'],
        ]);

        try {
            $purchase = $store->purchase($data['product_id'], $data['account_token'], $data['replaces_subscription_id'] ?? null);
        } catch (PurchaseVerificationFailed $exception) {
            return ApiResponse::error($exception->getMessage(), status: 422);
        }

        return ApiResponse::success('Mock store purchase completed.', [
            'purchase_token' => $purchase['token'],
            'product_id' => $purchase['product_id'],
        ], 201);
    }
}
