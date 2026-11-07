<?php

namespace App\Services\Billing;

use App\Models\AdminAuditLog;
use App\Models\SubscriptionPlan;
use App\Models\SubscriptionPlanVersion;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use RuntimeException;

/**
 * Admin changes to the plan catalog. A price/quota/entitlement change is a
 * new draft version that is then published; the previous published version
 * is archived (still referenced by its subscribers, never edited).
 */
class PlanManagement
{
    public function __construct(
        private readonly EntitlementCatalog $catalog,
    ) {}

    /** New draft, pre-filled from the latest version so admins only change what they mean to. */
    public function createDraft(SubscriptionPlan $plan, User $admin, array $values = []): SubscriptionPlanVersion
    {
        $this->authorize($admin);

        if ($plan->versions()->where('status', 'draft')->exists()) {
            throw new RuntimeException('This plan already has a draft version.');
        }

        $base = $plan->versions()->orderByDesc('version')->first();

        $data = array_merge([
            'price_amount' => $base?->price_amount ?? 0,
            'currency' => $base?->currency ?? 'IDR',
            'billing_interval' => $base?->billing_interval ?? ($plan->is_free ? 'none' : 'month'),
            'billing_interval_count' => $base?->billing_interval_count ?? 1,
            'entitlements' => $base?->entitlements ?? $this->catalog->defaults(),
            'provider_products' => $base?->provider_products ?? [],
        ], $values);

        $this->validate($plan, $data);

        $version = SubscriptionPlanVersion::create([
            ...$data,
            'entitlements' => $this->catalog->validate($data['entitlements']),
            'subscription_plan_id' => $plan->id,
            'version' => ($plan->versions()->max('version') ?? 0) + 1,
        ])->refresh();

        AdminAuditLog::record($admin, 'plan_version_drafted', $version, $version->only(['version', 'price_amount', 'currency', 'billing_interval', 'entitlements', 'provider_products']));

        return $version;
    }

    public function deleteDraft(SubscriptionPlanVersion $version, User $admin): void
    {
        $this->authorize($admin);

        AdminAuditLog::record($admin, 'plan_version_draft_deleted', $version, ['version' => $version->version]);
        $version->delete(); // the model refuses anything but drafts
    }

    public function publish(SubscriptionPlanVersion $version, User $admin): SubscriptionPlanVersion
    {
        $this->authorize($admin);

        if ($version->status !== 'draft') {
            throw new RuntimeException('Only a draft can be published.');
        }

        $this->validate($version->plan, $version->only(['price_amount', 'currency', 'billing_interval', 'billing_interval_count', 'entitlements', 'provider_products']));

        return DB::transaction(function () use ($version, $admin) {
            SubscriptionPlanVersion::where('subscription_plan_id', $version->subscription_plan_id)
                ->where('status', 'published')
                ->get()
                ->each(fn (SubscriptionPlanVersion $old) => $old->forceFill(['status' => 'archived'])->save());

            $version->forceFill(['status' => 'published', 'published_at' => now()])->save();

            AdminAuditLog::record($admin, 'plan_version_published', $version, ['version' => $version->version, 'plan' => $version->plan->key]);

            return $version;
        });
    }

    /** @throws ValidationException */
    private function validate(SubscriptionPlan $plan, array $data): void
    {
        $errors = [];

        if (! in_array($data['billing_interval'], SubscriptionPlanVersion::INTERVALS, true)) {
            $errors['billing_interval'] = 'Unknown billing interval.';
        }
        if ($plan->is_free && ($data['price_amount'] !== 0 || $data['billing_interval'] !== 'none')) {
            $errors['price_amount'] = 'The Free plan has no price and no billing interval.';
        }
        if (! $plan->is_free && ($data['price_amount'] <= 0 || $data['billing_interval'] === 'none')) {
            $errors['price_amount'] = 'A paid plan needs a price and a recurring billing interval.';
        }
        if (! preg_match('/^[A-Z]{3}$/', (string) $data['currency'])) {
            $errors['currency'] = 'Use a 3-letter ISO currency code.';
        }
        if (($data['billing_interval_count'] ?? 0) < 1 || $data['billing_interval_count'] > 12) {
            $errors['billing_interval_count'] = 'Between 1 and 12.';
        }
        foreach (($data['provider_products'] ?? []) as $provider => $product) {
            if (! in_array($provider, Providers\PaymentProviderRegistry::KEYS, true) || ! is_string($product) || $product === '') {
                $errors["provider_products.{$provider}"] = 'Unknown provider or empty product id.';
            }
        }
        if (! isset($data['entitlements']['storage_limit_bytes'])) {
            $errors['entitlements.storage_limit_bytes'] = 'Every plan must state its storage quota.';
        }

        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }

        $this->catalog->validate($data['entitlements']);
    }

    private function authorize(User $admin): void
    {
        if (! $admin->hasAdminPermission('plans.manage')) {
            throw new AuthorizationException('Missing the plans.manage permission.');
        }
    }
}
