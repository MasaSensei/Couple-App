<?php

use App\Services\Billing\EntitlementCatalog;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
 * Phase 8 — subscriptions. See docs/billing/subscriptions.md.
 *
 * Deliberately NOT created (evaluated, see the doc §4):
 *   - payment_providers: providers are code + env credentials, not data.
 *   - subscription_entitlements: entitlements are a JSON snapshot on the
 *     plan version and copied onto each subscription; manual grants are
 *     `manual` subscriptions, so no per-couple override table is needed.
 */
return new class extends Migration
{
    public function up(): void
    {
        // Entitlement keys the backend knows how to enforce. Created from code
        // (EntitlementCatalog); admins may rename/describe, never invent keys.
        Schema::create('entitlement_definitions', function (Blueprint $table) {
            $table->id();
            $table->string('key', 64)->unique();
            $table->string('name', 100);
            $table->string('description', 500)->nullable();
            $table->string('type', 20); // boolean | bytes | integer
            $table->json('default_value'); // value when no plan says otherwise
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('subscription_plans', function (Blueprint $table) {
            $table->id();
            $table->string('key', 64)->unique();
            $table->string('name', 100);
            $table->string('description', 1000)->nullable();
            $table->string('status', 20)->default('hidden'); // active | hidden | retired
            $table->boolean('is_free')->default(false);
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
        });

        // Price, interval and entitlements of a plan at a point in time.
        // Published versions are immutable (model guard): changing a price
        // publishes a new version, and existing subscriptions keep theirs.
        Schema::create('subscription_plan_versions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('subscription_plan_id')->constrained()->restrictOnDelete();
            $table->unsignedInteger('version');
            $table->string('status', 20)->default('draft'); // draft | published | archived
            $table->unsignedBigInteger('price_amount')->default(0); // minor units
            $table->char('currency', 3)->default('IDR');
            $table->string('billing_interval', 10)->default('none'); // none | month | year
            $table->unsignedSmallInteger('billing_interval_count')->default(1);
            $table->json('entitlements'); // key => value, validated against definitions
            $table->json('provider_products')->nullable(); // provider => store product id
            $table->timestamp('published_at')->nullable();
            $table->timestamps();

            $table->unique(['subscription_plan_id', 'version']);
        });

        // At most one published version per plan.
        DB::statement("CREATE UNIQUE INDEX subscription_plan_versions_one_published ON subscription_plan_versions (subscription_plan_id) WHERE status = 'published'");

        // Opaque, per-couple id handed to the store at purchase (Google
        // obfuscatedAccountId / Apple appAccountToken) so a purchase token can
        // only ever be attached to the couple it was bought for.
        Schema::table('couples', function (Blueprint $table) {
            $table->uuid('billing_account_token')->nullable()->unique();
        });

        Schema::create('couple_subscriptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('couple_id')->constrained()->restrictOnDelete();
            $table->foreignId('subscription_plan_version_id')->constrained()->restrictOnDelete();
            $table->foreignId('purchased_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('provider', 20); // mock | google_play | app_store | manual
            $table->string('provider_subscription_id', 255)->nullable();
            $table->string('status', 20); // pending | active | grace_period | cancelled | expired | payment_failed | suspended
            $table->string('ended_reason', 30)->nullable(); // expired | refunded | chargeback | replaced | admin
            // Set by an admin suspension; provider syncs then keep it suspended
            // (they may still end it) until an admin reinstates it.
            $table->boolean('admin_suspended')->default(false);
            $table->boolean('auto_renew')->default(true);
            $table->timestamp('current_period_start')->nullable();
            $table->timestamp('current_period_end')->nullable();
            $table->timestamp('grace_ends_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->timestamp('ended_at')->nullable();
            // Provider's own timestamp of the state we last applied; older
            // states (delayed / out-of-order webhooks) are ignored.
            $table->timestamp('provider_state_at')->nullable();
            $table->timestamp('last_synced_at')->nullable();
            $table->json('entitlements_snapshot');
            $table->timestamps();

            $table->unique(['provider', 'provider_subscription_id']);
            $table->index(['couple_id', 'status']);
        });

        // One live subscription per couple: a second purchase can never stack.
        DB::statement("CREATE UNIQUE INDEX couple_subscriptions_one_live ON couple_subscriptions (couple_id) WHERE status IN ('pending', 'active', 'grace_period', 'cancelled', 'payment_failed', 'suspended')");

        // Money movements reported by a provider. No card data ever: stores
        // never give it to us and the columns have no place for it.
        Schema::create('subscription_transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('couple_id')->constrained()->restrictOnDelete();
            $table->foreignId('couple_subscription_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('subscription_plan_version_id')->nullable()->constrained()->nullOnDelete();
            $table->string('provider', 20);
            $table->string('provider_transaction_id', 255);
            $table->string('type', 20); // purchase | renewal | refund | chargeback | adjustment
            $table->bigInteger('amount'); // minor units, negative for refunds
            $table->char('currency', 3);
            $table->timestamp('occurred_at');
            $table->json('metadata')->nullable(); // non-sensitive provider fields only
            $table->timestamps();

            $table->unique(['provider', 'provider_transaction_id', 'type']);
        });

        // Append-only audit trail of every subscription change.
        Schema::create('subscription_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('couple_id')->constrained()->restrictOnDelete();
            $table->foreignId('couple_subscription_id')->nullable()->constrained()->nullOnDelete();
            $table->string('type', 40);
            $table->string('from_status', 20)->nullable();
            $table->string('to_status', 20)->nullable();
            $table->string('actor', 64); // user:{id} | admin:{id} | provider:{key} | system
            $table->string('reason', 500)->nullable();
            $table->json('data')->nullable();
            $table->timestamp('created_at')->useCurrent();
        });

        // Webhook idempotency + replay log. (provider, event_id) is unique, so a
        // duplicate delivery is recognised before anything is applied.
        Schema::create('payment_webhook_events', function (Blueprint $table) {
            $table->id();
            $table->string('provider', 20);
            $table->string('event_id', 255);
            $table->string('event_type', 64);
            $table->string('provider_subscription_id', 255)->nullable();
            $table->string('status', 20)->default('received'); // received | processed | ignored | failed
            $table->unsignedInteger('attempts')->default(0);
            $table->string('error', 500)->nullable();
            $table->json('payload'); // already signature-verified
            $table->timestamp('occurred_at')->nullable();
            $table->timestamp('processed_at')->nullable();
            $table->timestamps();

            $table->unique(['provider', 'event_id']);
        });

        // Short-lived record of "this couple is about to buy that plan version".
        Schema::create('subscription_purchase_intents', function (Blueprint $table) {
            $table->id();
            $table->foreignId('couple_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('subscription_plan_version_id')->constrained()->restrictOnDelete();
            $table->string('provider', 20);
            $table->string('product_id', 255);
            $table->timestamp('expires_at');
            $table->timestamp('consumed_at')->nullable();
            $table->timestamps();
        });

        // Fine-grained admin permissions (billing.view, billing.manage,
        // plans.manage). Empty by default: being an admin grants none of them.
        Schema::table('users', function (Blueprint $table) {
            $table->json('admin_permissions')->nullable();
        });

        // Append-only log of admin changes that are not tied to one couple
        // (plans, versions, entitlement definitions, permissions).
        Schema::create('admin_audit_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('admin_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('action', 64);
            $table->string('subject_type', 64);
            $table->unsignedBigInteger('subject_id')->nullable();
            $table->json('changes')->nullable();
            $table->timestamp('created_at')->useCurrent();
            $table->index(['subject_type', 'subject_id']);
        });

        app(EntitlementCatalog::class)->sync();
        app(EntitlementCatalog::class)->ensureFreePlan();
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_audit_logs');
        Schema::table('users', fn (Blueprint $table) => $table->dropColumn('admin_permissions'));
        Schema::dropIfExists('subscription_purchase_intents');
        Schema::dropIfExists('payment_webhook_events');
        Schema::dropIfExists('subscription_events');
        Schema::dropIfExists('subscription_transactions');
        Schema::dropIfExists('couple_subscriptions');
        Schema::table('couples', fn (Blueprint $table) => $table->dropColumn('billing_account_token'));
        Schema::dropIfExists('subscription_plan_versions');
        Schema::dropIfExists('subscription_plans');
        Schema::dropIfExists('entitlement_definitions');
    }
};
