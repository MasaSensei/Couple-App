<?php

/*
 * Monitoring settings. See docs/operations/monitoring.md.
 */
return [

    // One structured line per API request (method, route, status, duration).
    'request_log' => (bool) env('REQUEST_LOG_ENABLED', true),

    // A component is unhealthy when its last heartbeat is older than this.
    'heartbeat_stale_seconds' => (int) env('HEARTBEAT_STALE_SECONDS', 300),

    // Dead-man's switch URLs (e.g. Healthchecks.io / Better Stack heartbeat).
    // Pinged every minute by the scheduler and by a queued job; when the pings
    // stop the external service alerts. Empty = disabled.
    'heartbeat_urls' => [
        'scheduler' => env('HEARTBEAT_URL_SCHEDULER'),
        'queue' => env('HEARTBEAT_URL_QUEUE'),
    ],

    // Detailed /health/ready output requires this bearer token. Without it
    // the endpoint only returns the overall status (no component names).
    'health_token' => env('HEALTH_CHECK_TOKEN'),

    // Webhooks still unprocessed after this many minutes raise an alert.
    'webhook_stuck_minutes' => (int) env('ALERT_WEBHOOK_STUCK_MINUTES', 30),
];
