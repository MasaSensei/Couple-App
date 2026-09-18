<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CoupleController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::post('/auth/register', [AuthController::class, 'register']);
    Route::post('/auth/login', [AuthController::class, 'login']);

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);
        Route::patch('/me', [AuthController::class, 'updateProfile']);

        Route::post('/couple', [CoupleController::class, 'store']);
        Route::get('/couple', [CoupleController::class, 'show']);
        Route::post('/couple/join', [CoupleController::class, 'join']);
        Route::get('/couple/{coupleId}', [CoupleController::class, 'showById']);
    });
});
