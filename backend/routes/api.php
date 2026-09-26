<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CoupleController;
use App\Http\Controllers\Api\V1\DateController;
use App\Http\Controllers\Api\V1\DateCommentController;
use App\Http\Controllers\Api\V1\MemoryController;
use App\Http\Controllers\Api\V1\MemoryPhotoController;
use App\Http\Controllers\Api\V1\MemoryCommentController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::post('/auth/register', [AuthController::class, 'register']);
    Route::post('/auth/login', [AuthController::class, 'login']);

    Route::get('/health', function () {
        return response()->json([
            'success' => true,
            'message' => 'API is healthy.',
        ]);
    });

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);
        Route::patch('/me', [AuthController::class, 'updateProfile']);

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

        Route::post(
            '/memory-photos/{photo}/complete',
            [MemoryPhotoController::class, 'complete'],
        );

        Route::delete(
            '/memory-photos/{photo}',
            [MemoryPhotoController::class, 'destroy'],
        );

        Route::get(
            '/memory-photos/{photo}/content',
            [MemoryPhotoController::class, 'content'],
        );

        Route::get(
            '/memories/{memory}/comments',
            [MemoryCommentController::class, 'index'],
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
    });

    Route::get(
        '/couple/invite/{token}',
        [CoupleController::class, 'showInvitation']
    );
});
