<?php

namespace App\Services\Billing;

use App\Models\EntitlementDefinition;
use App\Models\SubscriptionPlan;
use App\Models\SubscriptionPlanVersion;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * The entitlement keys the backend can enforce.
 *
 * Keys live in code because each one needs enforcement code; everything
 * else (which plan grants what, quota sizes, names) is data that admins
 * change without a release. A key is only listed here once something
 * actually enforces it, so a plan can never advertise a benefit that does
 * not exist. Not defined yet, on purpose: memory_export and
 * additional_memory_features (not built) and advanced_customization (every
 * Phase 7 customization is free and stays free; there is nothing "advanced"
 * to sell yet).
 *
 * Enforced by:
 *   storage_limit_bytes    StorageQuotaService (upload / restore)
 *   premium_themes         CoupleThemeService (choosing a premium theme)
 *   premium_photo_booth    catalog `locked` flag only — Photo Booth renders
 *                          on-device and saves ciphertext, so the server
 *                          cannot see which template was used (docs §6).
 */
class EntitlementCatalog
{
    public const GIB = 1024 * 1024 * 1024;

    /**
     * Code-level definitions. `default` is the safety-net value used only if
     * no Free plan exists; the real Free values are on the Free plan version.
     */
    public const DEFINITIONS = [
        'storage_limit_bytes' => [
            'name' => 'Photo storage',
            'description' => 'Encrypted photo storage shared by the couple. Backups are not counted.',
            'type' => 'bytes',
            'default' => self::GIB, // placeholder
            'sort_order' => 10,
        ],
        'premium_themes' => [
            'name' => 'Premium themes',
            'description' => 'Choose themes marked premium in the catalog.',
            'type' => 'boolean',
            'default' => false,
            'sort_order' => 20,
        ],
        'premium_photo_booth' => [
            'name' => 'Premium Photo Booth templates',
            'description' => 'Use Photo Booth layouts marked premium in the catalog.',
            'type' => 'boolean',
            'default' => false,
            'sort_order' => 30,
        ],
    ];

    /** Adds missing definitions; keeps admin-edited names/descriptions. */
    public function sync(): void
    {
        foreach (self::DEFINITIONS as $key => $definition) {
            $row = EntitlementDefinition::firstOrNew(['key' => $key]);
            $isNew = ! $row->exists;
            $row->forceFill([
                'key' => $key,
                'type' => $definition['type'],
                'default_value' => $definition['default'],
                ...($isNew ? [
                    'name' => $definition['name'],
                    'description' => $definition['description'],
                    'sort_order' => $definition['sort_order'],
                ] : []),
            ])->save();
        }
    }

    /**
     * Every couple without a paid subscription is on the Free plan, so one
     * must always exist. Values are placeholders that admins change by
     * publishing a new Free version.
     */
    public function ensureFreePlan(): SubscriptionPlan
    {
        return DB::transaction(function () {
            $plan = SubscriptionPlan::free() ?? SubscriptionPlan::forceCreate([
                'key' => 'free',
                'name' => 'Free',
                'description' => 'Your private couple space, encrypted photos and the basics. Free forever.',
                'status' => 'active',
                'is_free' => true,
                'sort_order' => 0,
            ]);

            if (! $plan->publishedVersion()->exists()) {
                $version = SubscriptionPlanVersion::create([
                    'subscription_plan_id' => $plan->id,
                    'version' => ($plan->versions()->max('version') ?? 0) + 1,
                    'price_amount' => 0,
                    'currency' => 'IDR',
                    'billing_interval' => 'none',
                    'billing_interval_count' => 1,
                    'entitlements' => $this->defaults(),
                    'provider_products' => [],
                ]);
                $version->forceFill(['status' => 'published', 'published_at' => now()])->save();
            }

            return $plan;
        });
    }

    /** @return array<string, bool|int> */
    public function defaults(): array
    {
        return array_map(fn (array $definition) => $definition['default'], self::DEFINITIONS);
    }

    public function type(string $key): ?string
    {
        return self::DEFINITIONS[$key]['type'] ?? null;
    }

    /**
     * Validates a plan version's entitlement map: only known keys, values of
     * the right type. Missing keys mean "same as the default".
     *
     * @throws ValidationException
     */
    public function validate(array $entitlements): array
    {
        $errors = [];
        $clean = [];

        foreach ($entitlements as $key => $value) {
            $type = $this->type((string) $key);

            if ($type === null) {
                $errors["entitlements.{$key}"] = 'Unknown entitlement.';

                continue;
            }

            if ($type === 'boolean') {
                is_bool($value) ? $clean[$key] = $value : $errors["entitlements.{$key}"] = 'Must be true or false.';

                continue;
            }

            if (! is_int($value) || $value < 0) {
                $errors["entitlements.{$key}"] = 'Must be a non-negative whole number.';

                continue;
            }

            $clean[$key] = $value;
        }

        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }

        return $clean;
    }
}
