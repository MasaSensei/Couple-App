# Operations handbook

Start here to run, deploy and maintain the Couples App backend without any
prior context. Status as of 2026-11-07: **not production-ready** — see the
blockers in [docs/reports/phase-9-report.md](../reports/phase-9-report.md).

| Topic | Document |
|---|---|
| Architecture & environments | this file |
| Deploy, migrations, rollback, image verification | [deploy/README.md](../../deploy/README.md) |
| Security controls & audit findings | [security.md](security.md) |
| Monitoring, logs, alerts | [monitoring.md](monitoring.md) |
| Runbooks: alerts, incidents, secret rotation, payment reconciliation | [runbooks.md](runbooks.md) |
| Database: backup, restore, PITR, migration safety, audit | [database.md](database.md) |
| Disaster recovery plan, RPO/RTO, drills | [disaster-recovery.md](disaster-recovery.md) |
| Account deletion & data export policy | [account-deletion.md](account-deletion.md) |
| Performance & load test | [performance.md](performance.md) |
| Cost model | [cost-model.md](cost-model.md) |
| Flutter release checklists (Android, iOS) | [release-checklist.md](release-checklist.md) |
| Privacy, legal & store readiness | [privacy-legal.md](privacy-legal.md) |

Domain design docs (unchanged, still authoritative): encryption
([docs/security/encryption.md](../security/encryption.md)), storage reliability
& photo DR ([docs/storage/](../storage/)), subscriptions
([docs/billing/subscriptions.md](../billing/subscriptions.md)), themes & Photo
Booth ([docs/appearance/](../appearance/)).

## 1. Architecture

A **modular monolith**: one Laravel codebase, deployed as several processes.
No microservices — the team and load do not justify them.

```
 Flutter app (Android/iOS)
   │  HTTPS only (release builds refuse http://; ATS / no cleartext)
   │  photos encrypted on the device (AES-256-GCM, per-photo key from the Couple Key)
   ▼
 Caddy ── TLS, HSTS, /admin IP allowlist, 30 MB body limit
   ▼
 Nginx ── static assets, FastCGI, JSON access log, X-Request-Id
   ▼
 PHP-FPM: Laravel API + Filament admin
   │  Sanctum tokens (60-day expiry, rotation, device binding, revocation)
   │  rate limits, policies (couple membership), entitlements, validation
   ├──► PostgreSQL 17  (all metadata; never photo plaintext or keys)
   ├──► Redis          (cache, queue, locks, rate limits)
   ├──► Object storage PRIMARY  (provider A, private, ciphertext)
   └──► Object storage BACKUP   (provider B / other account, object lock, ciphertext)
 Queue worker(s) ── backup, integrity, repair, purge, webhooks, heartbeat
 Scheduler (one) ── sweeps, retention, DB backup, reconcile, alerts, heartbeat
 External monitor ── /health/ready + heartbeats (dead-man's switch), alerts a human
```

Responsibilities:

| Component | Owns | Failure impact | Mitigation |
|---|---|---|---|
| PHP-FPM app | HTTP API, auth, authorization | API down | stateless; restart policy; health check; scale replicas behind Nginx |
| PostgreSQL | all metadata | **total outage** (SPOF) | daily encrypted logical backups (+ restore check); managed PG with PITR recommended for production |
| Redis | queue, cache, rate limits, locks | uploads still work; backups/verify/webhooks wait; rate-limited routes fail; alerts still sent (fallback) | AOF persistence; `noeviction`; readiness 503 + external alert; `photos:backup-pending` re-dispatches |
| Primary store | ciphertext served to clients | photo downloads fail; uploads refused | repair from backup; readiness/alert |
| Backup store | independent ciphertext copy | photos stay `backing_up` (never shown as protected); sweeper retries | separate provider/account; alert |
| Queue worker | async work | backlog grows; heartbeat stale → alert | restart policy; health = heartbeat |
| Scheduler | periodic work | backups/sweeps stop; heartbeat stale → **external** alert | exactly one; `onOneServer()` locks |

Timeouts (fail fast, retry elsewhere): DB connect 3 s; S3 connect 5 s / request
60 s / 3 SDK retries (readiness probe: 2 s / 3 s / no retry); PHP request 60 s;
FPM terminate 65 s; Nginx FastCGI read 70 s; jobs 60–80 s with `retry_after` 90 s.

Connection budget: each PHP-FPM child holds at most one PostgreSQL connection.
`PHP_FPM_MAX_CHILDREN × app replicas + queue workers + scheduler + ~5 operator`
must stay below `PG_MAX_CONNECTIONS` (default 10×1 + 1 + 1 + 5 = 17 < 100). Add
PgBouncer (transaction mode) before exceeding ~70.

## 2. Environments

| | Development | Staging | Production |
|---|---|---|---|
| Where | developer machine, `docker-compose.yml` | own host, `deploy/docker-compose.prod.yml` | own host, same compose |
| Server | `php artisan serve` (dev only) | Nginx + PHP-FPM images | Nginx + PHP-FPM images |
| Config | `backend/.env` from `.env.example` | `deploy/env/staging.env` from example | `deploy/env/production.env` from example |
| `APP_ENV` / `APP_DEBUG` | `local` / true | `staging` / **false** | `production` / **false** (container refuses to start otherwise) |
| Database | local container `couples` (+ `couples_test`) | own DB, synthetic data only | own DB |
| Object storage | 2× SeaweedFS on one host | own buckets + keys | provider A + provider B, own keys |
| Redis | no password, local | password, internal network | password, internal network |
| API URL (app build) | `http://10.0.2.2:8000/api/v1` | `https://staging-api.<domain>/api/v1` | `https://api.<domain>/api/v1` |
| Logs | file + stderr | JSON stderr, `debug` | JSON stderr, `info` |
| Billing | mock store | mock off; store sandbox accounts | store production (not implemented yet) |
| Admin MFA | off (`ADMIN_MFA_REQUIRED=false`) | required | required + IP allowlist |

Rules: production credentials never exist outside the production host and the
secret store; no `.env` is committed (`.gitignore` covers `.env*`, `deploy/env/*.env`,
`deploy/verify/*.env`, keystores); staging never receives a copy of production data.
