<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;

/**
 * One structured access-log line per API request. Source for latency, error
 * rate, request volume, status distribution and auth-failure metrics.
 * Logs the route pattern (not the raw path), never bodies, headers or query.
 */
class LogRequest
{
    public function handle(Request $request, Closure $next): Response
    {
        return $next($request);
    }

    public function terminate(Request $request, Response $response): void
    {
        if (! config('observability.request_log') || ! $request->is('api/*')) {
            return;
        }

        $start = defined('LARAVEL_START') ? LARAVEL_START : $request->server('REQUEST_TIME_FLOAT');
        $status = $response->getStatusCode();

        Log::info('http.request', [
            'method' => $request->method(),
            'route' => $request->route()?->uri() ?? 'unmatched',
            'status' => $status,
            'duration_ms' => $start ? (int) round((microtime(true) - $start) * 1000) : null,
            'user_id' => $request->user()?->getAuthIdentifier(),
            'ip' => $request->ip(),
            'auth_failure' => in_array($status, [401, 429], true) || ($status === 422 && $request->is('api/v1/auth/login')),
        ]);
    }
}
