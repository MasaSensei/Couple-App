# PostgreSQL: production readiness, backup & restore

Design background: [docs/storage/reliability.md §14](../storage/reliability.md) (backup encryption) and
[docs/storage/disaster-recovery.md](../storage/disaster-recovery.md) (photo + DB disaster).

## 1. Audit (2026-11-07)

| Check | Result |
|---|---|
| Foreign keys | all relations constrained; delete behaviour deliberate: shared couple content `SET NULL` on user delete (memories, photos, **dates since Phase 9**), `RESTRICT` on memories/photos from couples (photos leave only through the purge) |
| FK indexes | 11 foreign keys had **no index**, incl. `couple_members.user_id`, read on almost every request. Added with `CREATE INDEX CONCURRENTLY` (`2026_11_08_100300`). 0 invalid indexes after applying on dev |
| Constraints | partial unique index "one live subscription per couple", `(provider, event_id)` webhook idempotency, couple max 2 members enforced in service + `unique(couple_id,user_id)` |
| N+1 | `QueryBudgetTest`: `GET /memories`, `/memories/timeline`, `/dates`, `/memories/{id}/photos` run the **same number of queries for 2 and 20 items** |
| Pagination | `/memories` paginated. **Not paginated:** `/dates`, `/memories/{id}/photos`, comments — acceptable at couple scale (tens–hundreds of rows); add cursor pagination before allowing very large memories |
| Transactions | account deletion, token refresh, device revocation, quota reservation, subscription state changes run in transactions; quota uses a row lock on the couple |
| Connection limits | 1 connection per FPM child; budget in [README §1](README.md#1-architecture); `DB_CONNECT_TIMEOUT=3` |
| Slow queries | `log_min_duration_statement=500` ms in the production compose |
| Migration safety | CI: `migrate:fresh → rollback → migrate`; rules in [deploy/README.md §5](../../deploy/README.md#5-migrations-rules) |

## 2. Backup strategy

| | Now (implemented, tested) | Production recommendation |
|---|---|---|
| Method | daily 02:00 logical `pg_dump -Fc`, streamed through libsodium sealed box (public key only on the server), uploaded to the **backup** store's `db-backups` bucket, SHA-256 recorded, stored copy re-downloaded and verified | keep, **plus** managed PostgreSQL with PITR (WAL, 7 days) *or* WAL-G to the backup store |
| Pre-deploy | `db:backup` before every migration (deploy.sh) | same |
| Offsite | backup store = separate provider/account from primary | same; DB host ≠ backup provider |
| Encryption | X25519 sealed box; secret key **offline** with 2 operators (password manager + paper in safe) | same |
| Retention | object lock 30 days (dev GOVERNANCE, production **COMPLIANCE**), versioned | 30 daily; add 12 monthly if required by policy |
| RPO | 24 h (daily dump) | ≤ 5 min with PITR |
| Verification | `db:restore-check` weekly where the operator identity exists + after each key rotation | weekly on the drill host |

The dump is a full logical copy; size today: 87 KB (dev). Measure dump/restore
time on staging with production-like volume before launch.

## 3. Restore check (weekly)

On an isolated drill host (never the production app server — it must not hold the secret key):

```bash
DB_BACKUP_RESTORE_IDENTITY=/secure/db-backup.key php artisan db:restore-check            # latest
DB_BACKUP_RESTORE_IDENTITY=/secure/db-backup.key php artisan db:restore-check --backup=<id>
```

Downloads, checks SHA-256, decrypts as a stream into `pg_restore` into a scratch
database, compares row counts with those recorded at backup time and checks
invariants, then drops the scratch DB. Result is stored on the backup row and
alerted on failure.

Evidence: 2026-11-07 backup #3 → `restore passed in 2.8s` (dev); also scenario F of the failure drill.

## 4. Restore (disaster)

1. **Stop writers**: `dc stop app queue scheduler` (keep `postgres`).
2. Pick the backup: latest succeeded (`database_backups` table, or the newest object in the `db-backups` bucket if the DB is gone; SHA-256 from the backup log/alert).
3. Restore into a **new, empty** database (the command refuses a non-empty target):
   ```bash
   dc run --rm -e DB_BACKUP_RESTORE_IDENTITY=/secure/db-backup.key migrate \
     php artisan db:restore --database=couples_restored [--object=<key> --sha256=<hex>]
   ```
4. Point `DB_DATABASE` at `couples_restored`, `dc up -d app queue scheduler`, run `dc exec app php artisan migrate --force` (no-op unless the backup predates a release).
5. `photos:reconcile` → expect `orphan_*` objects for photos uploaded after the backup (their nonce/MAC rows are lost; do **not** delete them). Tell affected couples to re-upload those photos (originals stay on their phones until upload is verified).
6. `ops:alerts`, smoke test, then keep the old database for 7 days before dropping it.

Never restore over the live database; never run `migrate:fresh`/`db:wipe` in production.
