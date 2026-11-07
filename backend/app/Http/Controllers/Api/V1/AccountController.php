<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Responses\ApiResponse;
use App\Services\AccountService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AccountController extends Controller
{
    public function __construct(private readonly AccountService $accounts) {}

    /** DELETE /api/v1/me — requires the current password. */
    public function destroy(Request $request): JsonResponse
    {
        $data = $request->validate(['password' => ['required', 'string', 'max:128']]);

        $result = $this->accounts->delete($request->user(), $data['password']);

        return ApiResponse::success('Your account has been deleted.', $result);
    }

    /** GET /api/v1/me/export */
    public function export(Request $request): JsonResponse
    {
        return ApiResponse::success('Your data export.', $this->accounts->export($request->user()));
    }
}
