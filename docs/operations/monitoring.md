# Monitoring, logging & alerting

> **Status:** everything below is implemented and tested in code. The
> **external** pieces (uptime monitor, heartbeat service, log platform, Slack
> channel) are **not connected yet** because no staging/production host exists.
> Until they are, monitoring is configuration, not an active service.

## 1. Signals and where they come from

| Area | Signal | Source |
|---|---|---|
| Application | request volume, latency (`duration_ms`), status distribution, error rate, auth failures | `http.request` JSON line per API request (`LogRequest` middleware) + Nginx JSON access log |
| | auth failures | `auth_failure: true` on 401/429 and failed logins; `auth.login_failed` (email hash only) |
| | unhandled errors | Laravel `error` logs with `request_id`; API returns the same `request_id` to the client |
| Infrastructure | CPU, memory, disk, container restarts | host agent of the monitoring provider (or `docker stats`) — not in the app |
| | container health | Docker health checks: FPM ping (app), heartbeat age (queue, scheduler), `/nginx-health` (web), `pg_isready`, `redis-cli ping` |
| | DB / Redis availability | `GET /api/v1/health/ready` |
| | DB connections | `select count(*) from pg_stat_activity` (runbook) |
| Queue | backlog, failed jobs | `ops:alerts` (`queue_backlog` > threshold, `failed_jobs`) |
| | worker alive / processing latency | queue heartbeat: a job dispatched every minute must run within 5 min |
| Scheduler | alive | scheduler heartbeat every minute (DB) + external ping |
| Storage | upload failures, backup pending, checksum mismatch, repair failure, provider outage | `ops:alerts` (from Phase 6 `StorageHealthService`) + Filament storage dashboard |
| | capacity | provider console / billing alerts (per provider) |
| Backups | DB backup age, last restore check | `db_backup_stale`, `db_restore_failed`, `db_restore_untested` |
| Subscription | webhook failures, stuck webhooks, state inconsistency | `webhook_stuck`, `subscription_state_inconsistent`; daily reconciliation (runbooks.md) |

## 2. Health endpoints

| Endpoint | Purpose | Touches |
|---|---|---|
| `GET /api/v1/health` (and `/up`) | liveness: PHP answers | nothing |
| `GET /api/v1/health/ready` | readiness: 200 or 503. With `Authorization: Bearer $HEALTH_CHECK_TOKEN`: per-component `ok`, `ms`, `detail` (exception class only, never connection strings) | DB, Redis, both stores (2 s/3 s probe, no retries), scheduler & queue heartbeat age |

No rate limiter on `/health/ready` (the limiter lives in Redis; readiness must
answer when Redis is down — verified: 503 with `redis: RedisException`).

**Use `/health/ready` for monitors and deploy smoke tests only — never as a
load-balancer / container health check.** It includes external object storage:
if a load balancer removed every app instance whenever a storage provider had
an outage, dates, memories text and login would go down too. Container and
proxy health use the FPM ping, heartbeats and `/nginx-health` (see the
compose file). In the dev drill a stopped storage container made readiness take
~12 s (Docker Desktop DNS lookup of a missing host); against a real provider the
probe's 2 s connect / 3 s request timeouts apply. Monitors should use a 20 s timeout.

## 3. Logs

- Production: `LOG_CHANNEL=stderr` with `JsonFormatter` → Docker `json-file` (20 MB × 5 per container) → ship to the log platform.
- Every line carries `extra.request_id` (Laravel Context, also inherited by queued jobs dispatched during the request).
- Redaction (`App\Logging\RedactSensitiveData`, on every channel): values of keys matching password/secret/token/authorization/cookie/session/api key/private key/couple key/recovery/wrapped/nonce/mac/signature/identity/credential, Bearer tokens, Sanctum tokens, Recovery Keys and `token=`/`password=` in strings.
- Never logged by design: request/response bodies, query strings (Nginx logs `$uri`), photo bytes, keys.
- Retention: 30 days in the log platform (no user content in logs; IPs are personal data → document in privacy policy).

## 4. Alerts (need a human)

`php artisan ops:alerts` runs every 15 min, writes to the `alerts` channel
(`ALERT_LOG_CHANNELS=stderr,slack`), re-sends an active alert every 6 h, logs
`Resolved:` when it clears. If Redis is down the de-duplication is skipped and
alerts are still sent. Each alert links `docs/operations/runbooks.md#<code>`.

| Code | Level | Means |
|---|---|---|
| `database_down`, `redis_down` | critical | dependency unreachable |
| `scheduler_down`, `queue_down` | critical | heartbeat older than 5 min |
| `primary_unreachable`, `backup_unreachable` | critical | object store unreachable |
| `repair_failed` | critical | photo with no verified copy |
| `integrity_mismatch` | critical | checksum mismatch found |
| `db_backup_missing`, `db_backup_stale` | critical | no backup in `max_age_hours` (26 h) |
| `db_restore_failed` | critical | last restore check failed |
| `backup_pending` | warning | photo backups pending > threshold |
| `degraded` | warning | photo has one copy / missing metadata |
| `failed_jobs` | warning | failed queue jobs exist |
| `queue_backlog` | warning | backlog above threshold |
| `db_restore_untested` | warning | backup never restore-tested |
| `webhook_stuck` | warning | payment webhook unprocessed > 30 min |
| `subscription_state_inconsistent` | warning | active past period end + leeway |
| `*_check_failed` | critical | an alert source itself crashed |

**External (must be configured at the provider):**

| Check | Alert when | Why external |
|---|---|---|
| HTTPS uptime on `/api/v1/health/ready` (with token), every 1 min from 2 regions | 2 consecutive non-200 | catches host/network/TLS/DB/Redis failures |
| Heartbeat `HEARTBEAT_URL_SCHEDULER`, period 1 min, grace 5 min | ping missing | the scheduler cannot report its own death |
| Heartbeat `HEARTBEAT_URL_QUEUE`, period 1 min, grace 5 min | ping missing | worker stuck or Redis down |
| Error-rate rule on `http.request` logs: 5xx > 2 % for 10 min | | |
| Latency rule: p95 `duration_ms` > 1500 ms for 15 min | | |
| Disk > 80 % on host / DB volume | | |
| TLS certificate < 14 days | | |

Not alerted on purpose (no action possible / noisy): single 5xx, individual
failed logins, single slow request, info-level business events.
