# Runbooks

Short, actionable procedures. `dc` below means
`docker compose -f deploy/docker-compose.prod.yml --env-file deploy/env/<env>.env -p couples-<env>`
on the environment's host. Never run destructive commands on production without
a fresh verified backup and the owner's approval.

Severity: **SEV1** data at risk or API down · **SEV2** degraded (backups, queue,
one store) · **SEV3** no user impact yet.

## Alert runbooks

### database_down
SEV1. `dc ps postgres` · `dc logs --tail 100 postgres` · disk: `df -h` on the host.
Restart: `dc restart postgres`. If the data volume is corrupt or lost → [database.md §Restore](database.md#4-restore).
API returns JSON 500 with `request_id` meanwhile; uploads are refused, nothing is half-written.

### redis_down
SEV2. `dc logs --tail 100 redis` · `dc restart redis`. AOF restores queued jobs.
While down: uploads work, backups/verification/webhooks wait; after recovery run
`dc exec app php artisan photos:backup-pending --older-than=0` and `billing:retry-webhooks --older-than=0`.

### scheduler_down
SEV2. `dc ps scheduler` · `dc logs --tail 100 scheduler` · `dc restart scheduler`.
Then check which daily jobs were missed (`db:backup` at 02:00 → run it by hand: `dc exec scheduler php artisan db:backup`).

### queue_down
SEV2. `dc logs --tail 100 queue` · `dc restart queue`. Backlog: `dc exec redis redis-cli -a "$REDIS_PASSWORD" LLEN "<prefix>queues:default"`.
Jobs are not lost while the worker is down (verified in the drill).

### primary_unreachable / backup_unreachable
SEV2 (SEV1 if both). Check the provider status page and credentials (expired key?).
Primary down: downloads fail, uploads refused; nothing to repair until it returns — then `photos:reconcile` and `photos:verify-integrity`.
Backup down: photos stay "backing up" (never shown as protected); when it returns `photos:backup-pending --older-than=0`.
Never delete or move objects by hand. Full photo DR: [docs/storage/disaster-recovery.md](../storage/disaster-recovery.md).

### repair_failed / integrity_mismatch / degraded
SEV2. Filament → Storage audits / Memory photos. Retry: admin actions "Verify integrity", "Repair".
If both copies are bad, the photo is lost for the server; the users may still have it on a device. Do not mark it healthy.

### backup_pending
SEV3→SEV2 if growing. Usually the backup store or worker. `photos:backup-pending --older-than=0`.

### db_backup_missing / db_backup_stale
SEV2. `dc exec scheduler php artisan db:backup` and read the error. Typical: backup bucket credentials, `pg_dump` version mismatch, disk.

### db_restore_failed / db_restore_untested
SEV2. Run the restore check on the **drill host** (it needs the offline secret key): [database.md §Restore check](database.md#3-restore-check-weekly).

### failed_jobs
SEV3. `dc exec app php artisan queue:failed` → fix cause → `queue:retry <id>` (or `all`). Jobs are idempotent (unique, re-check state).

### queue_backlog
SEV3. Is the worker running and healthy? Scale: `dc up -d --scale queue=2`.

### webhook_stuck
SEV2 (money). Filament → Payment webhooks. Provider outage → `billing:retry-webhooks` keeps retrying (max 20). Signature failures are never stored. See §Payment reconciliation.

### subscription_state_inconsistent
SEV3. `dc exec app php artisan billing:sweep`; if it persists, compare with the store console and reconcile.

### *_check_failed
SEV2. The alert job itself crashed: `dc logs scheduler | grep -i ops:alerts`.

## Incident response

1. **Acknowledge** in the alert channel; one person is incident lead.
2. **Assess**: SEV level, what users see, is data at risk? Get the `request_id` from a user report and search logs for it.
3. **Stabilise** before fixing: stop the bleeding (rollback: [deploy/README.md §Rollback](../../deploy/README.md#6-rollback); pause purge by stopping the scheduler if deletion is involved).
4. **Communicate**: status to users if > 15 min of SEV1.
5. **Fix**, verify with `/health/ready` and the smoke test.
6. **Postmortem** within 5 working days: timeline, root cause, what alerted (or not), actions. Store in `docs/reports/incidents/`.

Data breach suspected (credentials leaked, unauthorized access): treat as SEV1, rotate secrets (below), preserve logs, assess personal data affected, and follow the legal notification duty (e.g. GDPR 72 h to the authority) — see privacy-legal.md.

## Secret rotation

| Secret | How | Impact |
|---|---|---|
| `DB_PASSWORD` | `ALTER USER … PASSWORD …` → update env → `dc up -d app queue scheduler` | seconds |
| `REDIS_PASSWORD` | update env → `dc up -d redis app queue scheduler` | short queue pause |
| Storage keys (primary/backup/db-backup) | create new key at provider → update env → redeploy → verify `/health/ready` → delete old key | none |
| `HEALTH_CHECK_TOKEN` | update env + monitor | none |
| `APP_KEY` | **careful**: encrypts admin MFA secrets and sessions. Set `APP_PREVIOUS_KEYS=<old>` with the new `APP_KEY`, deploy, have admins re-save MFA (or re-enrol), then drop the previous key. API tokens are hashed, not encrypted — unaffected. | admins re-login |
| DB backup key pair | `db:backup-keygen` → new public key in env → keep the **old secret key** until every backup encrypted with it has expired (retention) | none |
| API tokens of a user | `POST /auth/logout-all` (user) or revoke devices; admin: delete tokens in DB | user re-login |
| Suspected compromise of the server | rotate all of the above; users' photo keys are not on the server — but because of TOFU (security.md S8) assume new devices enrolled during the compromise window may be affected and tell users to verify device fingerprints | |

## Payment reconciliation

> Real store integrations are **not implemented**; this is the procedure to run once they are.

Daily (automate when providers exist):
1. Export active subscriptions per provider (Play Console / App Store Connect).
2. `select provider, provider_subscription_id, status, current_period_end from couple_subscriptions where status in ('active','grace_period','cancelled');`
3. Differences → for each: `billing` re-fetch via webhook replay (`billing:retry-webhooks`) or admin "sync with provider". Never edit rows by hand; every manual change goes through Filament actions with a reason (audited).
4. Refunds/chargebacks: check `subscription_transactions` and that entitlements ended.
5. Monthly: revenue in the store reports vs. transactions table; record in finance.
