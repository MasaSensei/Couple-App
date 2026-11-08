<?php

namespace App\Http\Controllers\Api\V1\Billing;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Billing\CreatePurchaseIntentRequest;
use App\Http\Requests\Api\V1\Billing\RestorePurchasesRequest;
use App\Http\Requests\Api\V1\Billing\VerifyPurchaseRequest;
use App\Http\Responses\ApiResponse;
use App\Models\Couple;
use App\Models\SubscriptionPlan;
use App\Models\SubscriptionTransaction;
use App\Services\Billing\BillingException;
use App\Services\Billing\BillingPresenter;
use App\Services\Billing\EntitlementService;
use App\Services\Billing\Providers\PaymentProviderUnavailable;
use App\Services\Billing\StorageQuotaService;
use App\Services\Billing\SubscriptionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * The couple's subscription. Authorization = couple membership: every
 * endpoint resolves the caller's own couple and never takes a couple id,
 * so nobody can read or change another couple's billing.
 */
class SubscriptionController extends Controller
{
    public function __construct(
        private readonly SubscriptionService $subscriptions,
        private readonly BillingPresenter $presenter,
    ) {}

    public function plans(Request $request): JsonResponse
    {
        $couple = $this->couple($request);
        $current = $couple ? app(EntitlementService::class)->forCouple($couple)->planKey : null;

        return ApiResponse::success('Plans retrieved successfully.', [
            'plans' => SubscriptionPlan::offered()->with('publishedVersion')->get()
                ->map(fn (SubscriptionPlan $plan) => $this->presenter->plan($plan, $current))->values(),
        ]);
    }

    public function show(Request $request): JsonResponse
    {
        return $this->forCouple($request, fn (Couple $couple) => ApiResponse::success(
            'Subscription retrieved successfully.',
            $this->presenter->overview($couple, $request->user(), $this->subscriptions->liveSubscription($couple)),
        ));
    }

    public function entitlements(Request $request, EntitlementService $entitlements): JsonResponse
    {
        return $this->forCouple($request, function (Couple $couple) use ($entitlements) {
            $granted = $entitlements->forCouple($couple);

            return ApiResponse::success('Entitlements retrieved successfully.', [
                'plan_key' => $granted->planKey,
                'entitlements' => $granted->toArray(),
            ]);
        });
    }

    public function storage(Request $request, StorageQuotaService $quota): JsonResponse
    {
        return $this->forCouple($request, fn (Couple $couple) => ApiResponse::success(
            'Storage usage retrieved successfully.',
            ['storage' => $quota->usage($couple)],
        ));
    }

    public function createIntent(CreatePurchaseIntentRequest $request): JsonResponse
    {
        return $this->forCouple($request, function (Couple $couple) use ($request) {
            $plan = SubscriptionPlan::where('key', $request->validated('plan_key'))->first()
                ?? throw new BillingException('plan_unavailable', 'This plan is not available for purchase.', 404);

            return ApiResponse::success('Purchase intent created.', [
                'intent' => $this->subscriptions->createIntent($request->user(), $couple, $plan, $request->validated('provider')),
            ], 201);
        });
    }

    public function verify(VerifyPurchaseRequest $request): JsonResponse
    {
        return $this->forCouple($request, function (Couple $couple) use ($request) {
            $subscription = $this->subscriptions->verifyPurchase(
                $request->user(),
                $couple,
                $request->validated('provider'),
                $request->validated('product_id'),
                $request->validated('purchase_token'),
            );

            return ApiResponse::success('Purchase verified.', $this->presenter->overview($couple, $request->user(), $subscription->status === 'expired' ? null : $subscription));
        });
    }

    public function restore(RestorePurchasesRequest $request): JsonResponse
    {
        return $this->forCouple($request, function (Couple $couple) use ($request) {
            $results = $this->subscriptions->restore($request->user(), $couple, $request->validated('provider'), $request->validated('purchases'));

            return ApiResponse::success('Restore finished.', [
                'results' => $results,
                ...$this->presenter->overview($couple, $request->user(), $this->subscriptions->liveSubscription($couple)),
            ]);
        });
    }

    public function cancel(Request $request): JsonResponse
    {
        return $this->forCouple($request, function (Couple $couple) use ($request) {
            $this->subscriptions->cancelRenewal($request->user(), $couple);

            return ApiResponse::success(
                'Auto-renew is off. Your benefits continue until the end of the current period, and nothing is deleted.',
                $this->presenter->overview($couple, $request->user(), $this->subscriptions->liveSubscription($couple)),
            );
        });
    }

    public function transactions(Request $request): JsonResponse
    {
        return $this->forCouple($request, fn (Couple $couple) => ApiResponse::success('Transactions retrieved successfully.', [
            'transactions' => SubscriptionTransaction::where('couple_id', $couple->id)
                ->with('planVersion.plan')
                ->orderByDesc('occurred_at')
                ->orderByDesc('id')
                ->limit(100)
                ->get()
                ->map(fn ($transaction) => $this->presenter->transaction($transaction))
                ->values(),
        ]));
    }

    private function couple(Request $request): ?Couple
    {
        return $request->user()->coupleMemberships()->with('couple')->first()?->couple;
    }

    private function forCouple(Request $request, callable $action): JsonResponse
    {
        $couple = $this->couple($request);

        if ($couple === null) {
            return ApiResponse::error('User does not belong to a couple.', status: 404);
        }

        try {
            return $action($couple);
        } catch (BillingException $exception) {
            return ApiResponse::error($exception->getMessage(), ['code' => $exception->errorCode, ...array_diff_key($exception->data, ['couple_id' => true])], $exception->status);
        } catch (PaymentProviderUnavailable) {
            return ApiResponse::error('The store is not reachable right now. Your purchase is safe; please try again shortly.', ['code' => 'provider_unavailable'], 503);
        }
    }
}
