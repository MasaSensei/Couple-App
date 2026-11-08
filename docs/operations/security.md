# Security controls & audit (Phase 9)

Audit date 2026-11-07. Evidence = automated tests that pass today, or commands
that were actually run. This is an internal review by the development team,
**not** an independent security audit or penetration test (still required, §6).

## 1. Authentication

| Control | Implementation | Evidence |
|---|---|---|
| Password hashing | bcrypt (Laravel `hashed` cast) | — |
| Login brute force | `throttle:auth`: 5/min per email+IP, 30/min per IP; `Retry-After` | `ProductionHardeningTest` (case-insensitive email too) |
| Account enumeration | same error text; dummy hash for unknown emails (timing) | code review |
| Failed-login visibility | `auth.login_failed` log with 16-char SHA-256 prefix of the email (no email, no password) | `ObservabilityTest` |
| Token lifecycle | Sanctum token, **expires after 60 days** (`API_TOKEN_TTL_DAYS`); app rotates via `POST /auth/refresh` when < 14 days left; old token deleted | `ProductionHardeningTest`, Flutter `auth_lifecycle_test` |
| Logout / all sessions | `POST /auth/logout`, `POST /auth/logout-all` | tests |
| Device management | tokens bound to a device on `POST /devices`; `DELETE /devices/{id}` revokes device, its key packages and its tokens | Phase 5 tests |
| Expired token cleanup | `sanctum:prune-expired` daily | schedule |
| Password reset | **not implemented** (no e-mail delivery yet) — see §5 | — |

Password policy: users ≥ 8, ≤ 128 chars. Admins ≥ 12 with upper/lower case and digits (admin user form).

## 2. Authorization

- Every couple resource is resolved from the caller's own membership or checked by a policy (Memory, MemoryPhoto, MemoryComment, Couple); cross-couple access returns 403/404 — Phase 1–6 tests (`*AuthorizationTest`, `MemoryPhotoSecurityTest`, `EncryptionSecurityTest`).
- Subscription entitlements are enforced on the server (`EntitlementService`), premium themes rejected server-side; Photo Booth premium layouts are UI-only by design (E2E: the server never sees them).
- Admin panel: `is_admin` + MFA (TOTP, recovery codes, secrets encrypted with `APP_KEY`), optional `ADMIN_ALLOWED_IPS` (404 for others) and Caddy CIDR allowlist. Admin rights and billing permissions are granted **only via CLI** (`admin:role`, `admin:permission`) and audited; the panel cannot toggle `is_admin`.
- Admins cannot read photo content: the server never holds keys or plaintext (see encryption.md). The panel shows metadata only.

## 3. API security

| Item | State |
|---|---|
| Rate limits | auth, global API (240/min/user), uploads (60/min), public invite lookup (30/min/IP), billing (20/min), webhooks (120/min) |
| Validation | FormRequests on every write endpoint |
| CORS | `config/cors.php`: no browser origins unless `CORS_ALLOWED_ORIGINS` set |
| HTTPS | Caddy TLS + HSTS; app sends HSTS on HTTPS in production; release apps refuse `http://` |
| Headers | `nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`, CSP `default-src 'none'` on API, `Cache-Control: no-store` |
| Errors | JSON only; 500 = "Something went wrong." + `request_id`; container refuses `APP_DEBUG=true` outside local |
| Proxies | `TRUSTED_PROXIES` explicit; Nginx `real_ip` only from private ranges |
| Logs | redaction processor on every channel (passwords, tokens, keys, recovery keys, nonces/MACs, signatures) |
| Dependencies | `composer audit` → **0 advisories** after updating Filament/Livewire/Symfony/CommonMark (was 15); CI fails on any advisory |

## 4. Files & encryption

- Buckets private; photos only through `GET /memory-photos/{id}/content` (auth + couple policy, `no-store`, `octet-stream`).
- Size limits: request 30 MB (Caddy, Nginx, PHP), API validates `encrypted_size` and checksum (SHA-256) on completion; server never decodes images.
- Encryption design and limitations: [encryption.md](../security/encryption.md). Points that matter for release claims:
  - AES-256-GCM, random 96-bit nonce per photo, 128-bit tag verified on decrypt; AAD binds photo id + key slot; per-photo key via HKDF from the Couple Key; X25519 key wrapping per device; 256-bit Recovery Key.
  - **Key packages are not signed (trust on first use).** A malicious or compromised server could hand a new device a key it controls; users can detect it only by comparing fingerprints. Therefore marketing/privacy text must not claim that even a compromised server can never read photos.
  - Device revocation does not rotate the Couple Key (rotation designed, not implemented).
  - Losing every device and the Recovery Key = photos unrecoverable by anyone.
- Android: no cleartext in release, `allowBackup=false` + data extraction rules (device keys never go to cloud backup). iOS: ATS default (HTTPS), local networking only for dev.

## 5. Findings

| # | Severity | Finding | Status |
|---|---|---|---|
| S1 | Critical | No rate limit on login/register | **Fixed** |
| S2 | Critical | Monitoring blind to Redis/queue/scheduler outage (backup silently skipped 2026-11-07 02:00) | **Fixed** (DB heartbeats, readiness, external heartbeat, Redis-independent alerts) — external monitor still to be connected |
| S3 | Critical | Only a dev server / debug runtime existed | **Fixed** (production images, verified) |
| S4 | High | API tokens never expired | **Fixed** |
| S5 | High | 15 dependency advisories | **Fixed** (0) |
| S6 | High | Admin without MFA; admins could create admins in the panel | **Fixed** |
| S7 | High | No account deletion (store rejection) | **Fixed** (backend + app) |
| S8 | High | Key packages unsigned (TOFU) | **Open** — accepted for now, documented, must shape privacy claims; fix = sign packages with the approving device's identity key |
| S9 | Medium | Android cleartext enabled globally; iOS missing camera/photo usage strings (crash) | **Fixed** |
| S10 | Medium | App logged out on any startup error (offline) | **Fixed** (only 401 clears the session) |
| S11 | Medium | No password reset | **Open** — needs transactional e-mail provider |
| S12 | Medium | Couple Key not rotated on device revocation / member deletion | **Open** (design exists) |
| S13 | Low | `User::couple()` broken relation | **Fixed** (removed) |
| S14 | Info | Payments are mock only | **Open** (no store integration) |

## 6. Still required before public release

1. Independent review of the cryptographic protocol (key packages, recovery, TOFU) by an external party.
2. External penetration test of staging.
3. Password reset with e-mail verification.
4. Secret store for production env values (not a file on a laptop).
