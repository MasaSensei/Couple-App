<?php

use App\Http\Controllers\Api\V1\AccountController;
use App\Http\Controllers\Api\V1\Appearance\AppearanceController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\Billing\MockStoreController;
use App\Http\Controllers\Api\V1\Billing\SubscriptionController;
use App\Http\Controllers\Api\V1\Billing\WebhookController;
use App\Http\Controllers\Api\V1\Couple\CoupleKeyPackageController;
use App\Http\Controllers\Api\V1\Couple\CoupleKeyRecoveryPackageController;
use App\Http\Controllers\Api\V1\CoupleController;
use App\Http\Controllers\Api\V1\DateCommentController;
use App\Http\Controllers\Api\V1\DateController;
use App\Http\Controllers\Api\V1\DeviceController;
use App\Http\Controllers\Api\V1\MemoryCommentController;
use App\Http\Controllers\Api\V1\MemoryController;
use App\Http\Controllers\Api\V1\MemoryPhotoController;
use App\Http\Controllers\HealthController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::middleware('throttle:auth')->group(function () {
        Route::post('/auth/register', [AuthController::class, 'register']);
        Route::post('/auth/login', [AuthController::class, 'login']);
    });

    Route::get('/health', [HealthController::class, 'live']);
    // No throttle: the rate limiter lives in Redis, and readiness must still
    // answer (503 + details) when Redis is the thing that is down.
    Route::get('/health/ready', [HealthController::class, 'ready']);

    Route::middleware(['auth:sanctum', 'throttle:api'])->group(function () {
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::post('/auth/logout-all', [AuthController::class, 'logoutAll']);
        Route::post('/auth/refresh', [AuthController::class, 'refresh']);
        Route::get('/me', [AuthController::class, 'me']);
        Route::patch('/me', [AuthController::class, 'updateProfile']);
        Route::get('/me/export', [AccountController::class, 'export'])->middleware('throttle:6,1');
        // Password-confirmed; throttled like login so it cannot be used to guess passwords.
        Route::delete('/me', [AccountController::class, 'destroy'])->middleware('throttle:auth');

        Route::post('/couple/key-packages', [
            CoupleKeyPackageController::class,
            'store',
        ]);
        Route::get('/couple/key-packages', [
            CoupleKeyPackageController::class,
            'index',
        ]);
        Route::get('/couple/devices', [
            CoupleKeyPackageController::class,
            'devices',
        ]);
        Route::get('/couple/recovery-package', [
            CoupleKeyRecoveryPackageController::class,
            'show',
        ]);
        Route::put('/couple/recovery-package', [
            CoupleKeyRecoveryPackageController::class,
            'update',
        ]);

        // Subscriptions (docs/billing/subscriptions.md §11). Always the caller's own couple.
        Route::get('/billing/plans', [SubscriptionController::class, 'plans']);
        Route::get('/couple/subscription', [SubscriptionController::class, 'show']);
        Route::get('/couple/entitlements', [SubscriptionController::class, 'entitlements']);
        Route::get('/couple/storage', [SubscriptionController::class, 'storage']);
        Route::get('/couple/subscription/transactions', [SubscriptionController::class, 'transactions']);
        Route::middleware('throttle:20,1')->group(function () {
            Route::post('/couple/subscription/intents', [SubscriptionController::class, 'createIntent']);
            Route::post('/couple/subscription/verify', [SubscriptionController::class, 'verify']);
            Route::post('/couple/subscription/restore', [SubscriptionController::class, 'restore']);
            Route::post('/couple/subscription/cancel', [SubscriptionController::class, 'cancel']);
        });

        // Development stand-in for the store purchase sheet. Never registered in production.
        if (config('billing.providers.mock.enabled')) {
            Route::post('/billing/mock/purchases', [MockStoreController::class, 'purchase']);
        }

        Route::get('/appearance/catalog', [AppearanceController::class, 'catalog']);
        Route::get('/couple/theme', [AppearanceController::class, 'show']);
        Route::put('/couple/theme', [AppearanceController::class, 'update']);
        Route::delete('/couple/theme/customization', [AppearanceController::class, 'resetCustomization']);

        Route::post('/couple', [CoupleController::class, 'store']);
        Route::get('/couple', [CoupleController::class, 'show']);
        Route::post('/couple/join', [CoupleController::class, 'join']);
        Route::post(
            '/couple/invite',
            [CoupleController::class, 'createInvitation']
        );
        Route::get('/couple/{coupleId}', [CoupleController::class, 'showById']);

        Route::post(
            '/couple/invite/{token}/accept',
            [CoupleController::class, 'acceptInvitation']
        );

        Route::get(
            '/dates',
            [DateController::class, 'index']
        );

        Route::post(
            '/dates',
            [DateController::class, 'store']
        );

        Route::get(
            '/dates/{dateId}',
            [DateController::class, 'show']
        );

        Route::patch(
            '/dates/{dateId}',
            [DateController::class, 'update']
        );

        Route::post(
            '/dates/{dateId}/complete',
            [DateController::class, 'complete']
        );

        Route::post(
            '/dates/{dateId}/cancel',
            [DateController::class, 'cancel']
        );

        Route::get(
            '/dates/{dateId}/comments',
            [DateCommentController::class, 'index'],
        );

        Route::post(
            '/dates/{dateId}/comments',
            [DateCommentController::class, 'store'],
        );

        Route::get(
            '/memories/protection',
            [MemoryController::class, 'protection'],
        );

        Route::get(
            '/memories/timeline',
            [MemoryController::class, 'timeline'],
        );

        Route::get(
            '/memories',
            [MemoryController::class, 'index'],
        );

        Route::post(
            '/memories',
            [MemoryController::class, 'store'],
        );

        Route::get(
            '/memories/{memory}/photos',
            [MemoryPhotoController::class, 'index'],
        );

        Route::get(
            '/memories/{memory}/comments',
            [MemoryCommentController::class, 'index'],
        );

        Route::get(
            '/memories/{memory}',
            [MemoryController::class, 'show'],
        );

        Route::patch(
            '/memories/{memory}',
            [MemoryController::class, 'update'],
        );

        Route::delete(
            '/memories/{memory}',
            [MemoryController::class, 'destroy'],
        );

        Route::post(
            '/memories/{memory}/photos/upload',
            [MemoryPhotoController::class, 'upload'],
        );

        Route::patch(
            '/memory-photos/{photo}/encryption',
            [MemoryPhotoController::class, 'updateEncryption'],
        );

        Route::post(
            '/memory-photos/{photo}/upload',
            [MemoryPhotoController::class, 'uploadBinary'],
        )->middleware('throttle:uploads');

        Route::post(
            '/memory-photos/{photo}/complete',
            [MemoryPhotoController::class, 'complete'],
        );

        Route::delete(
            '/memory-photos/{photo}',
            [MemoryPhotoController::class, 'destroy'],
        );

        Route::get(
            '/memories/{memory}/photos/trash',
            [MemoryPhotoController::class, 'trash'],
        );

        Route::post(
            '/memory-photos/{photo}/restore',
            [MemoryPhotoController::class, 'restore'],
        )->withTrashed();

        Route::get(
            '/memory-photos/{photo}/content',
            [MemoryPhotoController::class, 'content'],
        );

        Route::post(
            '/memories/{memory}/comments',
            [MemoryCommentController::class, 'store'],
        );

        Route::patch(
            '/memory-comments/{comment}',
            [MemoryCommentController::class, 'update'],
        );

        Route::delete(
            '/memory-comments/{comment}',
            [MemoryCommentController::class, 'destroy'],
        );

        Route::post('/devices', [
            DeviceController::class,
            'store',
        ]);

        Route::get('/devices', [
            DeviceController::class,
            'index',
        ]);

        Route::delete('/devices/{device}', [
            DeviceController::class,
            'destroy',
        ]);
    });

    Route::get(
        '/couple/invite/{token}',
        [CoupleController::class, 'showInvitation']
    )->middleware('throttle:public');

    // Provider notifications: no user auth, signature-verified instead.
    Route::post('/billing/webhooks/{provider}', WebhookController::class)
        ->whereIn('provider', ['mock', 'google_play', 'app_store'])
        ->middleware('throttle:120,1');
});
