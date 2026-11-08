# Disaster Recovery Runbook (Phase 6, STEP 15)

Internal operations document. **Contains no credentials.** Credentials live in the operators' password manager, never in this repository or the app's `.env`.

Related: [reliability.md](reliability.md) (failure model, workflows), [../security/encryption.md](../security/encryption.md) (keys).

## 0. Ground rules during any incident

1. **Stop deleting.** Pause the purge before anything else. Comment out or disable `photos:purge` in the scheduler, or stop the `scheduler` container. Nothing else in the system deletes objects.
2. **Never write to the backup store** except through the documented restore steps. Do not "clean up" the backup buckets during an incident.
3. **Never restore from an unverified copy.** Every restored object must hash to `memory_photos.checksum`. Every restored DB dump must match `database_backups.sha256`.
4. **Keys are not in any backup.** Restoring storage and DB brings back ciphertext and metadata only. Users still need their devices or Recovery Key (failure G). No one can "restore" a lost key.
5. Log every action in the incident ticket: time, operator, command, result.

## 1. Who may run recovery

| Role | Can do | Holds |
|---|---|---|
| On-call engineer | Diagnose, pause purge, run `photos:reconcile`, `storage:alerts`, admin actions in Filament (retry backup, integrity check, repair) | Filament admin account |
| Storage operator (2 named people) | Everything above, plus restore objects from the backup store, rebuild a primary, restore the DB | Backup-store operator credential and the DB-backup **secret key** (offline, password manager, split access recommended) |
| Product owner | Approves user-facing communication and any data-loss statement | — |

The application's own credentials **cannot** delete backup versions (verified by `docker/storage/verify-immutability.sh`), so recovery never depends on them.

## 2. Identifying the incident

| Signal | Where | Likely scenario (reliability.md §4) |
|---|---|---|
| `primary_unreachable` / `backup_unreachable` alert | `storage/logs/alerts-*.log`, Slack if configured | A / D / I |
| `integrity_mismatch`, `repair_failed` alert | alerts log, Filament → Storage → Photo storage (filter *degraded*) | B / E |
| `db_backup_stale`, `db_restore_failed` alert | alerts log, Filament → Database backups | Backup pipeline broken (no data loss yet) |
| Spike of `missing` integrity results, purge or trash audit rows | Filament → Storage audit log | C / F (bug or accidental deletion) |
| App errors, empty tables, failed migrations | Laravel log | E |
| Users report "This device doesn't have the key" | Support | G, a key problem, **not** storage |

First diagnosis commands (read-only):

```bash
docker compose exec app php artisan storage:alerts
docker compose exec app php artisan photos:reconcile --no-queue
```

## 3. Choosing a valid backup

- **DB:** Filament → Database backups, or the `database_backups` table. Pick the newest row with `status=succeeded`, and prefer one with `restore_result=passed`. If the live DB is gone, list `postgres/` in the `db-backups` bucket with the operator credential. Object names carry UTC timestamps.
- **Before trusting a dump:** `db:restore-check` downloads it, compares the SHA-256, decrypts it (an authenticated stream with a final-chunk marker, so tampering and truncation fail), and restores it into a scratch DB.
- **Objects:** the photo backup is valid when its SHA-256 equals the DB checksum. The repair job and the drill both check this automatically. A noncurrent version can also be the source (`list-object-versions`, then `copy-object ?versionId=`), but only after hashing it.

## 4. Restoring the database

Restore into a **new** database and switch to it. The damaged database is never dropped or overwritten during the incident, so it stays available as evidence.

```bash
docker compose exec app php artisan down
docker compose stop queue scheduler
# Works even if the old DB is gone: uses only the object key and the operator's secret key.
# Omit --object to use the latest succeeded backup recorded in the (still working) DB.
docker compose run --rm app php artisan db:restore \
    --object=postgres/couples-<UTC timestamp>.dump.enc --sha256=<if known> \
    --database=couples_restored_<date> --identity=/path/to/secret.key
# Point DB_DATABASE at couples_restored_<date>, then:
docker compose up -d app queue scheduler
docker compose exec app php artisan migrate --force   # only adds migrations newer than the dump
```

`db:restore` refuses any target database that already has tables. A tampered or truncated dump fails authenticated decryption before anything is committed (`--exit-on-error`). Then go straight to §6, reconciliation. Bring the app back up (`php artisan up`) only after reconciliation is clean.

**Accepted loss (RPO):** rows created after the dump. Their objects survive but cannot be decrypted, because `nonce` and `mac` were lost with the rows. Reconciliation lists them as `orphan_*`. Keep them; never delete them during the incident.

## 5. Restoring object storage

**One or a few objects (B, C):** Filament → Photo storage → *Request repair*, or wait for the hourly integrity sweep. The repair re-verifies the source, copies it, re-hashes the result, and writes an audit row.

**Whole primary lost (D):**
1. Create a new primary bucket, versioned, with a lifecycle rule, at the same or a new provider. Give it a fresh app credential.
2. Point `PHOTOS_PRIMARY_*` at it. Keep the app in maintenance mode, or accept read fallback to the backup (reads already fall back to a verified backup copy).
3. Run reconciliation with sync jobs. Every row will be `missing_primary`, and each one is repaired from the backup and re-verified:
   ```bash
   docker compose run --rm -e QUEUE_CONNECTION=sync app php artisan photos:reconcile
   docker compose run --rm app php artisan photos:reconcile --no-queue   # expect missing_primary=0
   ```
   For large data sets use the queue (`QUEUE_CONNECTION=redis`) and watch Filament.
4. Once the reconciliation is clean, set the app live and re-enable the purge.

**Backup lost (I):** the primary stays authoritative. Create a new backup bucket with object lock and default retention, point `PHOTOS_BACKUP_*` at it, and set every `backup_status` to `pending`:

```sql
UPDATE memory_photos SET backup_status = 'pending', backup_integrity = NULL WHERE status = 'verified' AND primary_purged_at IS NULL;
```

`photos:backup-pending` then re-copies everything. Photos show as *Backing up* to users until done.

## 6. Reconciliation and verification

```bash
docker compose exec app php artisan photos:reconcile           # queues integrity checks for missing copies
docker compose exec app php artisan photos:reconcile --no-queue # report only
docker compose exec app php artisan storage:alerts
```

Done means:
- `missing_primary=0` and `missing_backup=0`;
- no `degraded` or `restoring` photos in Filament, except ones explained in the ticket;
- `orphan_*` reviewed and kept;
- one photo opened in the app by each affected couple, or by the drill client (see §8), to prove decryptability end to end.

## 7. Telling users

Users see per-photo and overall state from the server (*Protected*, *Backing up*, *Restoring*, *Needs attention*). During an incident:
- do not claim photos are safe until reconciliation is clean;
- for the RPO window (§4), tell affected couples that photos uploaded between `<backup time>` and `<incident time>` must be uploaded again from their phones. The originals are untouched on the device until upload is verified (Phase 5);
- never say "we can restore your photos" to someone who has lost every device and their Recovery Key: we cannot.

## 8. Drill: procedure and log

Repeatable, non-production only (`storage:dr-drill` refuses to run in production):

```bash
# live dev env: 5 encrypted photos through the real upload → verify → backup flow, then a DB backup
docker compose exec -e QUEUE_CONNECTION=sync app php artisan storage:dr-drill prepare --photos=5
docker compose exec app php artisan db:backup
# disaster: empty replacement primary bucket (operator), DB restored from the encrypted dump
aws s3api create-bucket --bucket photos-primary-dr ... && aws s3api put-bucket-versioning ...
docker compose exec -e DB_BACKUP_SCRATCH_DATABASE=couples_dr_drill app php artisan db:restore-check --backup=<id> --keep
docker compose run --rm --no-deps -e DB_DATABASE=couples_dr_drill -e PHOTOS_PRIMARY_BUCKET=photos-primary-dr \
    -e PHOTOS_PRIMARY_ACCESS_KEY=<operator> -e PHOTOS_PRIMARY_SECRET_KEY=<operator> \
    -e QUEUE_CONNECTION=sync -e CACHE_STORE=array app php artisan storage:dr-drill verify
# cleanup: dropdb couples_dr_drill; remove photos-primary-dr (operator)
```

The drill client key is kept in `storage/app/private/dr-drill-client/client.json`, outside the DB and the stores, standing in for the users' phones. The client side is a PHP stand-in using the same AES-256-GCM-with-AAD layout. The Flutter decrypt path is covered by its own tests.

### Drill log

**2026-11-06, dev (Docker, SeaweedFS ×2, PostgreSQL 17), operator: Claude Code session**

| # | Requirement | Result |
|---|---|---|
| 1 | Restore one encrypted photo | PASS. Each of the 5 photos was individually restored from the backup by `RepairMemoryPhoto` and re-hashed. Separately (STEP 8), one object version was restored after a delete: SHA-256 matched, 4 s |
| 2 | Restore DB metadata | PASS. Backup #2 (76,746 B, encrypted) restored into `couples_dr_drill` in 2.6 s. 5/5 drill rows present with `nonce`/`mac` |
| 3 | Restore several objects after primary loss | PASS. Replacement primary started empty (0 objects). 5/5 were `missing` before and repaired by reconciliation in 2.0 s |
| 4 | Checksum verification | PASS. 5/5 primary and backup copies `ok` against the restored DB checksums |
| 5 | Client decrypts restored copies with the valid key | PASS. 5/5 decrypted (GCM tag verified) to byte-identical original JPEGs |
| 6 | No plaintext on the server | PASS. No JPEG header or plaintext marker in any stored object. No marker or couple key in any text column of the restored DB |

Timings: new primary 5 s; DB restore 12 s (including container start); verify 22 s; **total 39 s** for 5 photos, rc=0, 23/23 checks passed.

Issues found during the drill and fixed:
- `db:restore-check` failed at first on 2 old dev rows that were `verified` but had no `key_id`/`nonce`/`mac`. Those rows exist in the live DB too, so this is a data problem, not a restore fault. It is now a WARNING in the restore detail, and the photos show `degraded` in Filament and alerts.
- `photos:reconcile` listed only the `couples/` prefix, so rows with other keys were reported as missing. It now lists whole buckets.
- A failed decrypt left `pg_restore` un-reaped and a stderr temp file behind. Both are now always cleaned up, and a test asserts it.

Not covered by this drill: a real second provider/account (dev shares one Docker host), production-size data, and a restore performed by someone other than the person who wrote the runbook. Repeat the drill before launch on the production providers, and then every quarter.
