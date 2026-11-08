# Subscriptions, entitlements and storage quota (Phase 8)

Status: **backend + Flutter UI done against a mock store. No real payment
provider is integrated yet** — Google Play Billing and Apple In-App Purchase
are registered but fail closed (§9). Nothing in this phase charges real money.

## 1. Principles

Never a paid feature, on every plan including Free:

- client-side (end-to-end) photo encryption and private storage,
- couple authorization, secure authentication, privacy,
- full access to existing memories and photos (view, download, delete),
- basic notifications (when they exist; there is no push system yet).

A subscription ending never deletes anything and never locks a couple out
of their own data. It only stops *adding* photos beyond the Free quota and
switching to *new* premium items.

## 2. Architecture

```
Flutter ──(plan key / opaque store token only)──► Laravel API
                                                   │
          SubscriptionService ──► PaymentProvider ─┼─► provider's server (Google / Apple / MockStore)
               │      ▲                            │
               │      └── WebhookReceiver ◄────────┘ signed notifications
               ▼
     SubscriptionLifecycle (only code that changes status, writes audit events)
               │
     EntitlementService ──► allows('premium_themes') / storageLimitBytes()
               │
     StorageQuotaService (upload / restore)   CoupleThemeService (premium themes)
```

| Piece | File |
|---|---|
| Entitlement keys (code) | `app/Services/Billing/EntitlementCatalog.php` |
| Resolution per couple | `app/Services/Billing/EntitlementService.php` |
| Quota | `app/Services/Billing/StorageQuotaService.php` |
| Lifecycle / state machine | `app/Services/Billing/SubscriptionLifecycle.php` |
| Purchase, restore, cancel, sync, sweep | `app/Services/Billing/SubscriptionService.php` |
| Providers | `app/Services/Billing/Providers/*` |
| Webhooks | `WebhookReceiver.php`, `app/Jobs/ProcessPaymentWebhook.php` |
| Admin actions | `AdminSubscriptionActions.php`, `PlanManagement.php`, `app/Filament/Resources/{SubscriptionPlans,CoupleSubscriptions,EntitlementDefinitions,PaymentWebhookEvents}` |
| Flutter | `frontend/lib/features/subscription/` |

Nothing in the app compares plan names. Code asks the entitlement service
for a key; plans are data.

## 3. Plans

Plans and prices are **data**, edited by admins with `plans.manage`:

- `subscription_plans`: key, name, description, status (`active` / `hidden` /
  `retired`), display order. Exactly one `is_free` plan, created by the
  migration and always active.
- `subscription_plan_versions`: price (minor units), currency, billing interval
  (`none` / `month` / `year`) and count, entitlements (JSON), store product id
  per provider. One `published` version per plan. **Published versions are
  immutable** (model guard); a change is a new draft → publish, which archives
  the previous one.

Placeholders (dev seeder `SubscriptionPlanSeeder`, not agreed business values):

| Plan | Price (IDR / month) | Storage | Premium themes | Premium Photo Booth |
|---|---|---|---|---|
| Free | 0 | 1 GiB | – | – |
| Love | 29.000 | 20 GiB | ✓ | – |
| Together+ | 59.000 | 100 GiB | ✓ | ✓ |

"Forever" was **not** used for the top tier: it is a recurring subscription,
and "Forever" reads like a lifetime purchase. A true lifetime purchase would
be a non-recurring product (`billing_interval = none`, paid) and needs its
own lifecycle rules; it is not supported yet.

In production the price users pay is the one configured in Play Console /
App Store Connect for the product id. The backend price is the reference
shown before purchase and recorded per version; keep them in sync when
publishing.

## 4. Data model

| Table | Purpose |
|---|---|
| `entitlement_definitions` | Keys the backend enforces; admins edit name/description only. |
| `subscription_plans`, `subscription_plan_versions` | Catalog + versioning (§3). |
| `couple_subscriptions` | One row per store subscription, owned by `couple_id`. `entitlements_snapshot` is copied from the version at purchase. Partial unique index: **one live subscription per couple**. `(provider, provider_subscription_id)` unique. |
| `subscription_transactions` | Money movements reported by the provider; unique `(provider, provider_transaction_id, type)`. No card data — there is no column for it and stores never send it. |
| `subscription_events` | Append-only audit trail (status changes, purchases, rejections, admin actions with reason). |
| `payment_webhook_events` | Signature-verified notifications; unique `(provider, event_id)` = idempotency. |
| `subscription_purchase_intents` | "This couple is buying that version" for 60 min. |
| `couples.billing_account_token` | Random UUID given to the store (Google `obfuscatedAccountId`, Apple `appAccountToken`). |
| `users.admin_permissions` | `billing.view`, `billing.manage`, `plans.manage`. |
| `admin_audit_logs` | Append-only log of catalog and permission changes. |

Evaluated and **not** created: `payment_providers` (providers are code +
credentials, not data) and `subscription_entitlements` (snapshot JSON on the
subscription + manual grants cover it).

## 5. Couple ownership rules

- The subscription belongs to the **Couple**. Both members get the same
  entitlements and both see status, renewal date and billing history.
- Either member may start a subscription while the couple has none.
- Only the **purchaser** can change plan or cancel renewal: store
  subscriptions are billed to their personal store account, and a partner
  must never control someone else's payment. The partner sees "Started by
  your partner" and who manages billing.
- A purchase is bound to the couple: the store records the couple's
  `billing_account_token`, and verification rejects a token whose account
  token differs (`account_mismatch`) or that is already linked to another
  couple (`belongs_to_another_couple`). Restore never transfers.
- Entitlements are resolved from current membership only. A member who
  leaves stops getting them; a new couple never inherits them.
- **Leaving / breaking up** (there is no "leave couple" feature yet; this is
  the policy for when it is built): the subscription stays with the couple
  record; the purchaser keeps control of billing in their store and is told
  to cancel it if neither partner will use the space; data access follows
  the couple-data rules of that feature, never the subscription.

## 6. Entitlements

| Key | Type | Enforced by |
|---|---|---|
| `storage_limit_bytes` | bytes | `StorageQuotaService` on upload session, encryption metadata, completion and restore |
| `premium_themes` | boolean | `CoupleThemeService`: choosing a theme with `is_premium` needs it (403 `entitlement_required`). The theme a couple already uses stays after expiry and can still be tweaked. |
| `premium_photo_booth` | boolean | Catalog `locked` flag; the app hides locked layouts. **UI-level only**: Photo Booth renders on the device and uploads ciphertext, so the server cannot see which layout was used. This is a deliberate trade-off of end-to-end encryption. |

Not defined (on purpose): `memory_export`, `additional_memory_features` (not
built) and `advanced_customization` (every Phase 7 customization is free and
stays free). Adding one = a definition in `EntitlementCatalog` + its
enforcement + tests; plans then switch it on without a release.

Resolution: code defaults ← Free plan's published version ← live entitled
subscription's snapshot. A paid snapshot never gives less than Free (max for
numbers, OR for booleans), so raising the Free quota helps everyone.

`isEntitled()` is time-based on top of the status (period end, grace end,
renewal leeway), so benefits end on time even if the scheduler is late.

## 7. Storage quota

- **Counted:** `encrypted_size` (the ciphertext actually stored) of verified,
  non-trashed photos. Photo Booth output is an ordinary encrypted photo.
- **Counted once:** the backup replica is an infrastructure cost and never
  doubles usage (`test_usage_counts_ciphertext_of_live_photos_once`).
- **Reserved, not used:** `pending` / `uploading` photos for at most
  `photos.abandoned_upload_hours` (24 h). They block parallel over-filling but
  are not shown as usage. Abandoned ones stop counting and are cleaned up by
  `photos:purge`.
- **Not counted:** the trash. Deleting frees space at once; restoring needs
  free space (the photo stays in the trash meanwhile, 30-day retention
  unchanged).
- The check runs under a row lock on the couple, so two partners cannot both
  take the last free bytes.
- When full: upload/restore get 422 `storage_quota_exceeded` with usage
  figures. Viewing, downloading, deleting, memories and every other feature
  keep working. Over quota after a downgrade: same, nothing is deleted.

## 8. Lifecycle

```
pending ──► active ◄──► cancelled ──► expired
              │ ▲          (renewal off; benefits until period end)
              ▼ │
         grace_period ──► payment_failed ──► expired
         suspended (store pause / admin hold) ──► active | expired
```

- **Cancel ≠ expire.** Cancel on the 10th of a period ending the 30th:
  status `cancelled`, `auto_renew=false`, benefits until the 30th, then
  `expired` (`ended_reason=expired`). Data untouched.
- **Renewal**: provider reports a new period + `renewal` transaction.
- **Payment failure**: `grace_period` (benefits continue until the
  provider's grace end) → `payment_failed` (benefits paused) → recover to
  `active` or end.
- **Refund / chargeback**: `expired` immediately with `ended_reason`
  `refunded` / `chargeback`, negative transaction recorded.
- **Plan change**: the store replaces the subscription; the old row ends
  with `ended_reason=replaced`.
- **Duplicate purchase** (both partners bought): never stacked; second one
  is refused with `duplicate_subscription` and audited so support can refund
  it in the store.
- Transitions are validated by `SubscriptionLifecycle::TRANSITIONS`;
  `expired` only re-opens when the provider itself reports the same
  subscription active again (Apple re-subscribe keeps its id).
- The client can never set a status: requests only carry plan key,
  provider, product id and the opaque token.

**Webhooks.** Signature first (invalid → 401, nothing stored). Then insert
under `(provider, event_id)` — a duplicate is acknowledged and dropped. The
job then **re-fetches** the subscription from the provider and applies that
state; states older than `provider_state_at` are ignored, so delayed or
out-of-order notifications cannot roll anything back.

**Provider outage.** Webhooks are stored and retried (`billing:retry-webhooks`
every 15 min, job backoff). `billing:sweep` (hourly) asks the provider about
overdue subscriptions; if it cannot, cancelled ones still end on time, and an
unconfirmed renewal gets a grace period instead of losing benefits.

## 9. Payment providers

| Provider | State |
|---|---|
| `mock` | Complete development store (`MockStore`): purchase, renew, fail, hold, pause, cancel, resume, expire, refund, chargeback, outage, HMAC-signed webhooks. Enabled only in `local`/`testing`; **hard-disabled in production** regardless of env. `php artisan billing:mock <action> <token>` drives it. |
| `google_play` | **Not integrated.** Needs a Play Console app, a service account with the Android Publisher API and a Pub/Sub push subscription. Implementation notes in `GooglePlayProvider.php` (subscriptionsv2.get, obfuscatedExternalAccountId check, acknowledge, OIDC-verified RTDN). |
| `app_store` | **Not integrated.** Needs an App Store Connect in-app purchase key and Server Notifications V2. Notes in `AppStoreProvider.php` (JWS chain verification, appAccountToken check). |

Store policy: digital subscriptions sold inside the Android/iOS apps must use
Google Play Billing / Apple IAP (check the current Google and Apple payment
policies and regional rules, e.g. alternative billing programmes, at
implementation time). A web/payment-gateway checkout is a separate decision
and needs legal review first.

Flutter side: purchases go through `PurchaseGateway`. Debug builds use
`MockPurchaseGateway`; release builds use `UnavailablePurchaseGateway`, which
disables the buttons and says purchases are not available yet. Integrating a
store = add the `in_app_purchase` plugin, implement a gateway that passes the
intent's `account_token` as obfuscatedAccountId / appAccountToken, and enable
the backend provider.

## 10. Admin (Filament)

Being `is_admin` grants **no** billing access. Permissions are granted only
from the server CLI (so no admin can grant themselves) and are audited:

```bash
php artisan admin:permission grant ops@example.com billing.view
```

| Permission | Allows |
|---|---|
| `billing.view` | Subscriptions list/detail with audit trail and transaction metadata; webhook log (no payloads, no purchase tokens). |
| `billing.manage` | Grant a plan for N days, extend/end a grant, suspend/reinstate (admin hold survives store syncs), resync from store. Every action needs a reason and writes a `subscription_events` row with `admin:{id}`. |
| `plans.manage` | Plans (create, rename, availability, order), draft/publish/delete-draft versions, entitlement names. Logged in `admin_audit_logs`. |

Refunds are made in Play Console / App Store Connect; the provider then
reports them like any other change. No billing screen shows photos, keys,
member emails or purchase tokens.

## 11. API (`/api/v1`, Sanctum, caller's own couple only)

| Method | Path | |
|---|---|---|
| GET | `/billing/plans` | Offered plans (published version), features, products of enabled providers |
| GET | `/couple/subscription` | Plan key, live subscription, entitlements, storage, enabled providers |
| GET | `/couple/entitlements` | Entitlements only |
| GET | `/couple/storage` | Usage |
| GET | `/couple/subscription/transactions` | Couple's billing history |
| POST | `/couple/subscription/intents` | `{plan_key, provider}` → product id + account token |
| POST | `/couple/subscription/verify` | `{provider, product_id, purchase_token}` |
| POST | `/couple/subscription/restore` | `{provider, purchases[]}` |
| POST | `/couple/subscription/cancel` | Purchaser only |
| POST | `/billing/webhooks/{provider}` | Unauthenticated, signature-verified |
| POST | `/billing/mock/purchases` | Dev only (route not registered when mock is off) |

Errors use the usual `{success:false, message, data:{code, ...}}` with
stable codes: `already_subscribed`, `not_purchaser`, `different_provider`,
`subscription_needs_attention`, `plan_unavailable`, `provider_unavailable`,
`purchase_invalid`, `account_mismatch`, `belongs_to_another_couple`,
`duplicate_subscription`, `manage_in_store`, `no_subscription`,
`storage_quota_exceeded`, `entitlement_required`.

## 12. Flutter UX rules

- Price always with its interval ("Rp 29.000 per month") and the renewal
  terms on the plan card and the confirmation dialog.
- "Cancel auto-renew" is a normal visible button for the purchaser with one
  plain confirmation stating the benefit end date and that nothing is deleted.
- No countdowns, no "are you sure you want to lose…" copy, no pre-selected
  upsells. Free is shown as a full plan.
- Every billing screen states what all plans keep (encryption, privacy,
  access to memories).

## 13. Tests

Backend `tests/Feature/Billing/*` (33 tests): lifecycle (free default,
purchase, renewal, cancel vs expiry, grace / payment failure / recovery,
refund, chargeback, duplicate + delayed webhooks, provider outage, plan
change, transition rules), entitlements (couple-only, forged status,
premium themes, plan edits not touching old subscriptions), storage (logical
counting, backup not doubled, reservations, full-quota behaviour, completion
recheck, expiry never deletes), security (webhook signatures, cross-couple
tokens, purchaser-only cancel, no token leaks, mock off in production, admin
permissions and audit).

Flutter `test/features/subscription/*` and `test/features/appearance/premium_theme_test.dart`.

## 14. Operations

| Command | Schedule |
|---|---|
| `billing:sweep` | hourly |
| `billing:retry-webhooks` | every 15 min |
| `admin:permission grant|revoke <email> <permission>` | manual |
| `billing:mock <action> <token>` | dev only |
| `db:seed --class=SubscriptionPlanSeeder` | dev only (placeholder plans) |

Env: `BILLING_RENEWAL_LEEWAY_HOURS` (24), `BILLING_GRACE_PERIOD_DAYS` (7,
fallback only), `BILLING_PURCHASE_INTENT_TTL_MINUTES` (60),
`BILLING_MOCK_ENABLED`, `BILLING_MOCK_WEBHOOK_SECRET`, and the provider
credentials in `config/billing.php`.

## 15. Known limitations

- No real store integration (§9); no real money has moved through this code.
- No push notifications: partners see subscription changes when the app
  refreshes the overview.
- Premium Photo Booth is enforced in the UI only (§6).
- No "leave couple" feature, so the leave policy (§5) is documented but not
  exercised.
- Store price vs backend reference price must be kept in sync manually.
