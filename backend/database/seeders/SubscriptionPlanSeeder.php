<?php

namespace Database\Seeders;

use App\Models\SubscriptionPlan;
use App\Models\SubscriptionPlanVersion;
use App\Services\Billing\EntitlementCatalog;
use Illuminate\Database\Seeder;

/**
 * PLACEHOLDER paid plans for development and demos. Names, prices and
 * quotas are not agreed business values: in production, plans are created
 * and priced by an admin with `plans.manage` in the admin panel, and store
 * prices are set in Play Console / App Store Connect.
 *
 * "Forever" was not used for the top tier on purpose: it is a recurring
 * subscription, and "Forever" reads like a lifetime purchase.
 */
class SubscriptionPlanSeeder extends Seeder
{
    private const GIB = EntitlementCatalog::GIB;

    public function run(): void
    {
        app(EntitlementCatalog::class)->ensureFreePlan();

        $this->plan('love', 'Love', 'More room for your memories, plus premium themes.', 10, 29_000, [
            'storage_limit_bytes' => 20 * self::GIB,
            'premium_themes' => true,
            'premium_photo_booth' => false,
        ]);

        $this->plan('together_plus', 'Together+', 'The most storage, every theme and every Photo Booth layout.', 20, 59_000, [
            'storage_limit_bytes' => 100 * self::GIB,
            'premium_themes' => true,
            'premium_photo_booth' => true,
        ]);
    }

    private function plan(string $key, string $name, string $description, int $order, int $monthlyPrice, array $entitlements): void
    {
        $plan = SubscriptionPlan::firstOrCreate(['key' => $key], [
            'name' => $name,
            'description' => $description,
            'status' => 'active',
            'is_free' => false,
            'sort_order' => $order,
        ]);

        if ($plan->publishedVersion()->exists()) {
            return;
        }

        $version = SubscriptionPlanVersion::create([
            'subscription_plan_id' => $plan->id,
            'version' => 1,
            'price_amount' => $monthlyPrice,
            'currency' => 'IDR',
            'billing_interval' => 'month',
            'billing_interval_count' => 1,
            'entitlements' => $entitlements,
            'provider_products' => [
                'mock' => "{$key}_monthly",
                'google_play' => "{$key}_monthly",
                'app_store' => "app.couple.{$key}.monthly",
            ],
        ]);

        $version->forceFill(['status' => 'published', 'published_at' => now()])->save();
    }
}
