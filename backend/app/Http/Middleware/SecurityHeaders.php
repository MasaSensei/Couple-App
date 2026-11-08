<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Baseline response headers. The reverse proxy may add the same headers; these
 * make the app safe even when it is reached without one.
 */
class SecurityHeaders
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        $headers = $response->headers;
        $headers->set('X-Content-Type-Options', 'nosniff');
        $headers->set('Referrer-Policy', 'no-referrer');
        $headers->set('X-Frame-Options', 'DENY');
        $headers->set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
        $headers->remove('X-Powered-By');

        if ($request->is('api/*')) {
            // API responses are JSON or ciphertext; nothing should render or cache them.
            $headers->set('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'");

            if (! $headers->has('Cache-Control') || $headers->get('Cache-Control') === 'no-cache, private') {
                $headers->set('Cache-Control', 'no-store, private');
            }
        }

        if ($request->isSecure() && app()->isProduction()) {
            $headers->set('Strict-Transport-Security', 'max-age='.config('security.hsts_max_age').'; includeSubDomains');
        }

        return $response;
    }
}
