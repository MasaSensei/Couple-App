<?php

namespace App\Http\Controllers;

use App\Services\Ops\HealthCheck;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class HealthController extends Controller
{
    /** Liveness: the PHP process answers. No dependencies are touched. */
    public function live(): JsonResponse
    {
        return response()->json(['success' => true, 'message' => 'API is healthy.']);
    }

    /**
     * Readiness: database, Redis, both photo stores and background heartbeats.
     * 503 when anything fails. Component details only with HEALTH_CHECK_TOKEN.
     */
    public function ready(Request $request, HealthCheck $health): JsonResponse
    {
        $result = $health->run();
        $token = config('observability.health_token');
        $authorised = filled($token) && hash_equals((string) $token, (string) $request->bearerToken());

        return response()->json(
            $authorised ? $result : ['status' => $result['status']],
            $result['status'] === 'ok' ? 200 : 503,
        );
    }
}
