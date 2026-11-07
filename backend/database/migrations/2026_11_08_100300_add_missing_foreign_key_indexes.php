<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/*
 * Indexes for foreign keys that had none (found by the Phase 9 DB audit:
 * docs/operations/database.md). Two reasons:
 *   - hot lookups: couple_members.user_id is read on almost every request
 *     (the caller's couple); personal_access_tokens.user_device_id on device
 *     revocation;
 *   - ON DELETE SET NULL / CASCADE from users must not seq-scan big tables
 *     (account deletion touches memories.created_by, admin_audit_logs.admin_id).
 *
 * CREATE INDEX CONCURRENTLY does not block writes, so this is safe on a live
 * production database. It cannot run inside a transaction, hence
 * $withinTransaction = false. IF NOT EXISTS makes a re-run after a partial
 * failure harmless (drop an INVALID index first if one is reported).
 */
return new class extends Migration
{
    public $withinTransaction = false;

    private const INDEXES = [
        'couple_members_user_id_index' => ['couple_members', 'user_id'],
        'personal_access_tokens_user_device_id_index' => ['personal_access_tokens', 'user_device_id'],
        'memories_created_by_index' => ['memories', 'created_by'],
        'couple_key_recovery_packages_couple_id_index' => ['couple_key_recovery_packages', 'couple_id'],
        'admin_audit_logs_admin_id_index' => ['admin_audit_logs', 'admin_id'],
        'couple_subscriptions_purchased_by_index' => ['couple_subscriptions', 'purchased_by'],
        'subscription_transactions_couple_id_index' => ['subscription_transactions', 'couple_id'],
        'subscription_events_couple_id_index' => ['subscription_events', 'couple_id'],
        'subscription_purchase_intents_couple_id_index' => ['subscription_purchase_intents', 'couple_id'],
        'subscription_purchase_intents_user_id_index' => ['subscription_purchase_intents', 'user_id'],
        'couple_theme_settings_updated_by_index' => ['couple_theme_settings', 'updated_by'],
    ];

    public function up(): void
    {
        foreach (self::INDEXES as $name => [$table, $column]) {
            DB::statement("CREATE INDEX CONCURRENTLY IF NOT EXISTS {$name} ON {$table} ({$column})");
        }
    }

    public function down(): void
    {
        foreach (array_keys(self::INDEXES) as $name) {
            DB::statement("DROP INDEX CONCURRENTLY IF EXISTS {$name}");
        }
    }
};
