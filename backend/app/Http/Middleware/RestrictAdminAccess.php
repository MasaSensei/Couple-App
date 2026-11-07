<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\IpUtils;
use Symfony\Component\HttpFoundation\Response;

/**
 * Optional IP allowlist for the admin panel (ADMIN_ALLOWED_IPS). Responds 404
 * so the panel's existence is not advertised.
 */
class RestrictAdminAccess
{
    public function handle(Request $request, Closure $next): Response
    {
        $allowed = config('security.admin.allowed_ips', []);

        if ($allowed !== [] && ! IpUtils::checkIp((string) $request->ip(), $allowed)) {
            abort(404);
        }

        return $next($request);
    }
}
