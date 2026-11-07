<?php

/*
 * Production hardening knobs. See docs/operations/security-hardening.md.
 */
return [

    // API tokens (Sanctum personal access tokens) expire this many days after
    // they are issued. The app rotates its token through POST /auth/refresh
    // before that, so an active user is never logged out, while a leaked
    // token stops working on its own.
    'token_ttl_days' => (int) env('API_TOKEN_TTL_DAYS', 60),

    'rate_limits' => [
        // Per email+IP and per IP, per minute, for login/register.
        'auth_per_identity' => (int) env('RATE_LIMIT_AUTH_PER_IDENTITY', 5),
        'auth_per_ip' => (int) env('RATE_LIMIT_AUTH_PER_IP', 30),
        // Per authenticated user (or IP), per minute, for the whole API.
        'api_per_user' => (int) env('RATE_LIMIT_API_PER_USER', 240),
        // Ciphertext uploads per user per minute.
        'uploads_per_user' => (int) env('RATE_LIMIT_UPLOADS_PER_USER', 60),
        // Unauthenticated invite lookups per IP per minute (token guessing).
        'public_per_ip' => (int) env('RATE_LIMIT_PUBLIC_PER_IP', 30),
    ],

    'admin' => [
        // Admins must enrol an authenticator app before using the panel.
        'mfa_required' => (bool) env('ADMIN_MFA_REQUIRED', true),
        // Comma-separated IPs/CIDRs allowed to reach /admin. Empty = no IP
        // restriction (rely on the reverse proxy / VPN instead).
        'allowed_ips' => array_values(array_filter(array_map('trim', explode(',', (string) env('ADMIN_ALLOWED_IPS', ''))))),
        'password_min_length' => 12,
    ],

    // Sent on HTTPS responses in production only.
    'hsts_max_age' => (int) env('HSTS_MAX_AGE', 31536000),
];
