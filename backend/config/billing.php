<?php

/*
 * Subscription & monetization. See docs/billing/subscriptions.md.
 *
 * Prices, quotas and plan names are NOT here: they live in the database
 * (subscription_plans / subscription_plan_versions) and are managed in the
 * admin panel. This file only holds operational settings and provider
 * credentials.
 */
return [

    // Leeway after `current_period_end` during which an auto-renewing
    // subscription stays entitled while we wait for the store to confirm the
    // renewal (delayed webhook, provider outage). Not applied to subscriptions
    // whose renewal was cancelled.
    'renewal_leeway_hours' => (int) env('BILLING_RENEWAL_LEEWAY_HOURS', 24),

    // Grace period used when a provider reports a failed renewal but does not
    // say how long it keeps retrying (mock / manual). Google and Apple send
    // their own grace end, which wins.
    'default_grace_period_days' => (int) env('BILLING_GRACE_PERIOD_DAYS', 7),

    // A purchase intent (the couple's chosen plan before paying) is only
    // honoured for this long.
    'purchase_intent_ttl_minutes' => (int) env('BILLING_PURCHASE_INTENT_TTL_MINUTES', 60),

    'providers' => [

        // Development / test store. Simulates a store entirely inside this app.
        // NEVER enable in production: anyone could "buy" a plan for free.
        'mock' => [
            'enabled' => (bool) env('BILLING_MOCK_ENABLED', in_array(env('APP_ENV'), ['local', 'testing'], true)),
            'webhook_secret' => env('BILLING_MOCK_WEBHOOK_SECRET', 'mock-webhook-secret-for-dev-only'),
        ],

        // Not integrated yet: needs a Play Console app, a service account with
        // the Android Publisher API and a Pub/Sub push subscription.
        'google_play' => [
            'package_name' => env('BILLING_GOOGLE_PLAY_PACKAGE'),
            'service_account_json' => env('BILLING_GOOGLE_PLAY_SERVICE_ACCOUNT'),
            'pubsub_audience' => env('BILLING_GOOGLE_PLAY_PUBSUB_AUDIENCE'),
        ],

        // Not integrated yet: needs App Store Connect in-app purchase key and
        // App Store Server Notifications V2 configured.
        'app_store' => [
            'bundle_id' => env('BILLING_APP_STORE_BUNDLE_ID'),
            'issuer_id' => env('BILLING_APP_STORE_ISSUER_ID'),
            'key_id' => env('BILLING_APP_STORE_KEY_ID'),
            'private_key' => env('BILLING_APP_STORE_PRIVATE_KEY'),
            'environment' => env('BILLING_APP_STORE_ENVIRONMENT', 'Sandbox'),
        ],
    ],
];
