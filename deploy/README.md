# Deployment

Everything needed to build, deploy, verify and roll back the backend. Written so
another developer can operate the system without the history of this project.

- Architecture & environments: [docs/operations/README.md](../docs/operations/README.md)
- Runbooks (alerts, incidents, secret rotation, payment reconciliation): [docs/operations/runbooks.md](../docs/operations/runbooks.md)
- Database backup/restore: [docs/operations/database.md](../docs/operations/database.md)

> **Status (2026-11-07):** the production images and this compose stack were
> verified on a developer machine (`deploy/verify`). **No staging or production
> host exists yet**; nothing has been deployed anywhere. Production deploys
> require explicit approval from the project owner.

## 1. What runs where

| Service | Image | Role | Replicas |
|---|---|---|---|
| `caddy` | `caddy:2.10-alpine` | TLS (Let's Encrypt), HSTS, admin IP allowlist, only public entry (80/443) | 1 |
| `web` | `couples-web:<sha>` | Nginx: static Filament assets, FastCGI to `app`, JSON access log | 1 |
| `app` | `couples-app:<sha>` | PHP-FPM: API + admin panel (`CONTAINER_ROLE=web`) | 1 (scale later) |
| `queue` | `couples-app:<sha>` | `queue:work redis` (backup, verify, repair, purge, webhooks, heartbeat) | 1+ |
| `scheduler` | `couples-app:<sha>` | `schedule:work` (exactly one) | 1 |
| `migrate` | `couples-app:<sha>` | one-off `migrate --force --isolated`, profile `ops` | run on demand |
| `postgres` | `postgres:17-alpine` | database, internal network only | 1 |
| `redis` | `redis:7-alpine` | cache, queue, locks; password; AOF; `noeviction` | 1 |

Object storage (primary + backup) is **outside** this stack: two independent
providers/accounts configured in the env file.

Networks: `edge` (caddy↔web), `internal` (no internet route: app↔postgres/redis),
`egress` (app → object storage, store APIs, heartbeat monitors). Postgres and
Redis publish **no** ports.

## 2. One-time host setup (per environment)

1. Docker Engine + compose plugin; a non-root `deploy` user in the `docker` group; firewall: 22 (from VPN only), 80, 443.
2. Copy `deploy/` to the host. Create `deploy/env/<env>.env` from the matching
   `*.env.example` (`chmod 600`). Fill every `<…>` and SECRET from the secret store.
   - `APP_KEY`: `docker run --rm couples-app:<sha> php artisan key:generate --show` — unique per environment.
   - `DB_BACKUP_PUBLIC_KEY`: from `php artisan db:backup-keygen`; the **secret half goes offline** (see database.md).
   - Staging and production never share a database, bucket, key or APP_KEY.
3. DNS `A/AAAA` for `DOMAIN` → host. Caddy obtains certificates on first start.
4. Registry login (`docker login <registry>`), then the first deploy (§4).
5. Create the first admin: `docker compose … exec app php artisan admin:role grant <email>` (the user registers in the app first); they enrol MFA on first panel login.
6. External monitoring: uptime check on `https://<DOMAIN>/api/v1/health/ready` with header `Authorization: Bearer $HEALTH_CHECK_TOKEN`, and two heartbeat checks (`HEARTBEAT_URL_SCHEDULER`, `HEARTBEAT_URL_QUEUE`, period 1 min, grace 5 min). See monitoring.md.

## 3. Release pipeline

```
push / PR ──► CI (.github/workflows/backend.yml, flutter.yml)
               composer validate · composer audit · Pint · migrate fresh/rollback/migrate
               · 350+ tests · production config cache · Docker build (non-root, debug refused)
          ──► push images <registry>/couples-{app,web}:<git-sha>         (to add: needs registry)
          ──► deploy staging  (deploy.sh staging <sha>)                   (to add: needs host)
          ──► smoke test + manual checks on staging
          ──► APPROVAL by project owner
          ──► deploy production (CONFIRM_PRODUCTION=yes deploy.sh production <sha>)
```

## 4. Deploy (any environment)

```bash
deploy/scripts/deploy.sh staging <git-sha>
CONFIRM_PRODUCTION=yes deploy/scripts/deploy.sh production <git-sha>   # only after staging + approval
```

The script, in order:

1. Pulls `couples-app:<sha>` and `couples-web:<sha>`.
2. Ensures `postgres` and `redis` are healthy.
3. **Pre-deploy encrypted DB backup** with the *previous* image (`db:backup`, aborts on failure).
4. Runs migrations **once** in a one-off container (`migrate --force --isolated`; the lock prevents two runs). App containers never migrate on start.
5. Recreates `app`, `queue`, `scheduler`, `web` and waits for their health checks
   (`queue`/`scheduler` are healthy only when their heartbeat is fresh).
6. Runs `deploy/scripts/smoke-test.sh` against the public URL (liveness, readiness with every dependency, 401 without token, JSON 404, mock store not routed, HSTS).
7. On smoke failure: re-deploys the previous tag and re-runs the smoke test.

Graceful shutdown: PHP-FPM finishes in-flight requests on `SIGQUIT` (30 s);
the queue worker gets `SIGTERM` and 95 s to finish its current job (longest job
timeout 80 s); jobs never acked are retried after `retry_after` (90 s).

## 5. Migrations: rules

- **Expand → migrate code → contract.** A release only *adds* (tables, nullable columns, indexes). Removing/renaming happens in a later release, after no running code uses it. So rolling back the code never needs a down-migration.
- Large-table indexes: `CREATE INDEX CONCURRENTLY` with `$withinTransaction = false` (see `2026_11_08_100300_add_missing_foreign_key_indexes.php`).
- **Destructive migrations** (drop/rename/type change, data rewrite) require: a fresh verified backup (`db:backup` + `db:restore-check` on staging), the migration run on a staging copy first, a written rollback plan, and owner approval.
- CI runs `migrate:fresh → migrate:rollback → migrate` on every change.

## 6. Rollback

| Situation | Action |
|---|---|
| Smoke test fails during deploy | automatic: previous tag re-deployed |
| Problem found later, schema unchanged/expanded | `deploy.sh <env> <previous-sha>` (skips nothing: migrate is a no-op) |
| Bad data written by the new release | stop writers (`docker compose … stop queue scheduler`), fix forward or restore (database.md §Restore); never `migrate:rollback` in production without owner approval |
| Image itself broken (won't start) | `deploy.sh <env> <previous-sha>`; containers keep the old version until the new one is healthy only for `web` — `app` restarts are a short (~seconds) interruption |

The current tag per environment is stored in `deploy/env/.<env>.current-tag`.

## 7. Verify the images locally (no TLS, isolated volumes)

```bash
docker compose -f deploy/docker-compose.prod.yml -f deploy/verify/docker-compose.verify.yml \
    --env-file deploy/verify/verify.env -p couples-verify up -d --wait postgres redis
docker compose … run --rm migrate
docker compose … up -d --wait app queue scheduler web
sh deploy/scripts/smoke-test.sh deploy/verify/verify.env     # HSTS check fails without TLS — expected
```

`verify.env` is generated per machine (random secrets, git-ignored). The verify
stack reaches the dev SeaweedFS through the dev network and therefore uses the
unique hostnames `verify-postgres` / `verify-redis` — the dev network also has
hosts called `postgres` and `redis`.

Verified 2026-11-07: smoke test passed (except HSTS, no TLS), readiness `503`
with `redis: RedisException` while Redis was stopped, deploy-style app recreation
served `200` immediately (after fixing Nginx DNS caching, §8).

## 8. Problems found while verifying (fixed)

1. `docker-php-ext-install opcache` fails on PHP 8.5 (OPcache is in core).
2. Nginx resolved `app` once at start; after every app redeploy it kept the old IP → permanent `502`. Now `resolver 127.0.0.11` + `server app:9000 resolve`.
3. `/health/ready` used the Redis-backed rate limiter → `500` instead of `503` when Redis was down. Throttle removed from that route.
4. `/health/ready` took > 20 s when a store was down (SDK retries). Readiness now probes stores with 2 s / 3 s timeouts and no retries.
5. Verify stack accidentally reached the dev Redis through the shared network (same hostname). Unique aliases now.
