# Storage Reliability — Failure Model (Phase 6)

Internal engineering note. Contains no credentials.

**Claim we make:** a single failure (one storage copy, one provider account, one database, one buggy deploy) does not permanently lose a photo or its metadata, and we can detect and recover from it using procedures that have actually been tested.

**Claim we do not make:** "photos can never be lost". Losing every copy at once, or losing the encryption key, can still lose data. See [§5 Residual risks](#5-residual-risks).

Related: [`docs/security/encryption.md`](../security/encryption.md) (keys, recovery key). Disaster recovery runbook: `docs/storage/disaster-recovery.md` (STEP 15).

## 1. What we are protecting

| Asset | Where it lives | Reproducible? |
|---|---|---|
| Photo ciphertext | Primary object store, plus the backup object store | No. The plaintext exists only on users' devices |
| Photo metadata (`memory_photos`: `storage_key`, `checksum`, `encrypted_size`, `nonce`, `mac`, `key_id`, status) | PostgreSQL | No. Without `nonce`/`mac` the ciphertext **cannot be decrypted** |
| Memories, couples, membership | PostgreSQL | No |
| Encrypted key packages / recovery packages | PostgreSQL | No (needed to restore keys onto devices) |
| Couple Key (plaintext) | Users' devices and the user's Recovery Key only | Not our responsibility. It is never on the server or in a backup |

Ciphertext without its DB row is useless: `nonce` and `mac` exist only in PostgreSQL. **Database backups are therefore as critical as object backups.**

## 2. Starting point (audit, 2026-10-24)

- Ciphertext is stored on the `local` disk inside the app's bind mount, on the same host as PostgreSQL. There is one copy.
- There is no object backup and no database backup. No queue worker or scheduler is running.
- `MemoryPhotoService::delete()` deletes the object permanently and then soft-deletes the row, so soft delete protects nothing.
- `memory_photos.uploaded_by` and `memory_id` use `cascadeOnDelete`, so hard-deleting a user or memory removes photo rows.
- `failed` uploads leave orphaned objects. The user cannot retry or delete them.
- The SHA-256 of the ciphertext is checked only once, in `complete()`.
- The client already distinguishes a key problem (`CoupleKeyUnavailableException`) from an integrity problem (`PhotoVerificationException`).

## 3. Design principles

1. **The server only ever handles ciphertext.** Backup, verify, and repair copy bytes and compare SHA-256. They never decrypt.
2. **The trusted reference is the DB checksum.** The client computes it over the ciphertext it produced, and the server confirms it on upload. A checksum read from the object or the store itself is never trusted.
3. **Never overwrite a good copy with a suspect one.** A repair writes to a temporary key, verifies it, and only then promotes it.
4. **Failures are recorded as state, never resolved by deletion.** No code path deletes data because something is temporarily unavailable.
5. **Database and object store are two systems.** There is no cross-system transaction. Each step is an explicit status transition that is safe to retry.
6. **Backup lives in a different failure domain**: a different provider or account, with credentials the app cannot use to delete.
7. **`protected` is computed by the server** from verified evidence of both copies. Clients cannot set it.

## 4. Failure scenarios

Every row in "Test" refers to the failure-injection tests in STEP 14.

### A. Primary storage unavailable

| | |
|---|---|
| Trigger | Network outage, provider outage, disk full, wrong credentials |
| Detection | Storage calls throw. A health check (STEP 11) fails |
| Expected | **Upload:** the request fails with a clear, retryable error and the photo stays `pending`/`uploading`. It is not marked `failed` for a transient error, and it is never shown as saved. **Reads:** `content` falls back to a backup copy that is **verified and served as ciphertext through Laravel**; the client still verifies GCM. **Jobs:** verify and backup jobs back off and retry. No metadata or object is deleted |
| Must not | Mark photos `failed`/`degraded` en masse and trigger repair storms. Delete rows |
| Test | A (primary upload fails), I (mirror case) |

### B. Primary object corrupt

| | |
|---|---|
| Trigger | Bit rot, partial write, a bug that writes the wrong bytes |
| Detection | Scheduled integrity job: SHA-256 of the primary does not equal `memory_photos.checksum`. The client's checksum or GCM check fails on view (reported as `PhotoVerificationException`) |
| Expected | Primary copy is marked bad. The backup's SHA-256 is verified against the DB checksum. The backup is copied to a temp key on the primary, verified, then promoted. Re-verified, then marked healthy. Every step is recorded in an audit row |
| Must not | Restore from an unverified backup. Delete the bad primary before its replacement is verified. Change the ciphertext |
| Test | C |

### C. Accidental deletion

| | |
|---|---|
| Trigger | The user deletes by mistake, an admin error, a bug calls `deleteObject` |
| Detection | Integrity job: object missing while the row is live |
| Expected | A user delete is a **soft delete only**: the row has `deleted_at` set and the object is untouched. A purge happens after the retention period (configurable, default 30 days) and only through one audited command. Object versioning on the primary keeps the previous version. The backup is **not** deleted by the same operation; it has its own longer retention. A missing primary object is repaired from the backup (as in B) |
| Must not | A user delete reaching the backup. A memory or user delete cascading to photo rows |
| Test | G (delete during backup), plus a restore-from-trash test |

### D. Primary provider outage or account loss

| | |
|---|---|
| Trigger | A long regional outage, a suspended or compromised account, an expired billing account |
| Detection | Primary health check fails for longer than the threshold |
| Expected | The backup is in an **independent failure domain**: another provider or account, with separate credentials stored separately. An authorized operator can rebuild a new primary from the backup with the runbook (STEP 15) without the old primary account. Rows map to backup objects through the same `storage_key` |
| Must not | Backup credentials depending on the primary account. Recovery requiring the primary to be up |
| Test | I, plus the DR drill in STEP 15 |

### E. Database loss

| | |
|---|---|
| Trigger | Lost volume, a bad migration, an accidental `DROP` or `TRUNCATE`, host loss |
| Detection | App errors. Reconciliation finds objects with no rows |
| Expected | Restore the latest verified encrypted `pg_dump` from offsite storage. Run reconciliation: list objects against rows, and flag *row without object*, *object without row*, and *unfinished upload / pending backup*. Rows whose object exists are re-verified by checksum. Nothing is deleted automatically: orphaned objects are quarantined and reported |
| Accepted loss | Photos uploaded after the last DB backup: their objects survive but their `nonce`/`mac` are gone, so they cannot be decrypted. Backup frequency sets this window (RPO) |
| Test | F |

### F. Application bug deleting or overwriting many objects

| | |
|---|---|
| Trigger | A bad deploy loops `deleteObject`/`putObject`, or the storage key logic regresses |
| Detection | Integrity job mismatch or missing objects in bulk. A spike in delete operations in the audit log. An alert on degraded count |
| Expected | Primary versioning keeps previous versions. The app's backup credential is **write-only**: it has no delete or overwrite permission, and object lock/versioning on the backup is enabled where the provider supports it. Destructive operations (purge, repair) write audit rows. Repairs are rate-limited so a bug cannot "repair" everything with garbage |
| Must not | The same credential being able to delete the primary and the backup |
| Test | H, plus "app credential cannot delete backup" (STEP 10) |

### G. Encryption key loss

| | |
|---|---|
| Trigger | All of a couple's devices are lost and there is no Recovery Key |
| Detection | Client: `CoupleKeyUnavailableException`. The checksum still matches on the server |
| Expected | Reported as **"key needed"**, not as corruption. No repair is triggered. The server makes no attempt to decrypt and holds no key to try. The user is pointed to the Recovery Key flow from Phase 5 |
| Fact | **Backups do not fix key loss.** Restoring ciphertext without the key restores nothing readable |
| Test | J |

### H. Hard delete cascade (found in the audit)

| | |
|---|---|
| Trigger | Admin hard-deletes a user, or a memory is force-deleted |
| Expected | Photo rows survive or block the delete: `uploaded_by` becomes `nullOnDelete`, and a memory delete stays a soft delete. Removing photos happens only through the purge path |
| Test | Added with the migration in STEP 4/8 |

### I. Interrupted workflows

| Case | Handling |
|---|---|
| A worker dies after copying to the backup but before updating the DB | The job reruns. The object already exists with a matching SHA-256, so it is marked verified without writing again |
| Two workers on the same photo | Per-photo lock (Redis), and a job is unique per photo ID |
| A user deletes during a backup | The backup job re-reads the row before marking the copy verified. A trashed photo keeps its backup copy, and retention still applies; it never shows `protected` in normal views |
| The same upload is retried | Same `storage_key`. Overwriting is allowed only before `verified` |
| A copy has a checksum mismatch | The copy is not marked verified. The bad backup object is never promoted. Retry with backoff, then alert |

## 5. Residual risks

- **Simultaneous loss** of the primary, the backup, and every DB backup. Mitigated by independence, not eliminated.
- **The key-loss window:** no Recovery Key and no surviving device means the data is unrecoverable by design.
- **The RPO window** between DB backups: metadata for recent uploads may be lost even though the objects survive (§E).
- **Silent corruption between scheduled checks:** detected only at the next check, or when someone opens the photo.
- **A malicious operator with backup-admin credentials** can still destroy backups unless object lock is enabled. Whether it is enabled is recorded in STEP 10.
- **Legal or privacy deletion requests** conflict with long backup retention. Purge must also reach the backup after its retention ends. This is documented in STEP 8.

## 6. Targets (initial, to be revisited in STEP 16)

| Metric | Target |
|---|---|
| Copies of each protected photo | 2 (primary + independent backup) |
| Time from upload to `protected` | < 15 min under normal load |
| Full integrity sweep | Every 7 days. Recent uploads verified on upload |
| DB backup frequency (RPO) | Every 24 h for the MVP. Revisit if upload volume grows |
| User trash retention | 30 days (configurable) |
| Backup retention after purge | 30 days more (configurable) |
| Restore drill | Before Phase 6 sign-off, then on a regular schedule |

## 7. Decisions recorded

- Uploads keep going through Laravel (no presigned direct upload) for Phase 6, because it is the smaller change and keeps the existing verification step.
- Provider choice is deferred to STEP 16. The code depends only on Flysystem/S3-compatible APIs.
- Dev/test use **two SeaweedFS instances** with separate data volumes and credentials. MinIO was the first choice, but its community images are no longer published on Docker Hub, and quay.io returned 401. Before choosing SeaweedFS we ran a probe against `chrislusf/seaweedfs:4.48` (2026-10-24):
  - versioning is enabled automatically on a bucket created with object lock;
  - with COMPLIANCE retention, even the admin cannot delete a locked version;
  - a scoped `Read/Write/List` identity cannot delete versions or the bucket;
  - a plain delete only adds a delete marker.

  Whether `Write` alone allows deleting an *unlocked* version is still untested; that is STEP 10.
- PITR/WAL archiving is out of scope for the MVP. Logical encrypted `pg_dump` with a tested restore comes first.

## 8. Storage architecture

```
Flutter ── encrypts (AES-256-GCM) ──► Laravel API  /api/v1/memory-photos/*
                                          │  MemoryPhotoService (status workflow)
                                          ▼
                              PhotoStorage (interface)
                                          │
                     FlysystemPhotoStorage('photos_primary')     ◄── app reads/writes
                     FlysystemPhotoStorage('photos_backup')      ◄── backup job (STEP 4)
                                          │
                  disk photos_primary ────┴──── disk photos_backup
                  (S3 API, own creds)           (S3 API, own creds, object lock)
```

- **One implementation, two instances.** `FlysystemPhotoStorage` takes a disk name. Primary and backup differ only in configuration (`config/filesystems.php`, `PHOTOS_PRIMARY_*` / `PHOTOS_BACKUP_*`). Provider logic does not live in controllers or Flutter.
- **The interface streams.** `readStream()` replaced `getObject()`, which returned a local path that only worked on a local disk. `putObject()` accepts an upload or a stream, so a backup is a byte-for-byte copy of the ciphertext with no decryption.
- **Checksums are computed by us.** SHA-256 over the streamed bytes, compared with `memory_photos.checksum`. Provider ETags are never used as integrity evidence.
- **`throw => true`** on both disks: a storage failure is an exception, never a silent `false`.
- **Credentials.** Each store has an `operator` identity (bucket admin, never given to the app) and an `app` identity limited to its own bucket. The primary app key cannot read the backup bucket (verified).
- **The dev setup is not a failure domain.** Both stores share one Docker host. In production the backup must be a different provider or account (choice in STEP 16).

## 9. Backup workflow (STEP 4)

```
complete()  primary SHA-256 == DB checksum ──► status=verified, backup_status=pending
                │  dispatch BackupMemoryPhoto (a queue outage is reported, never fails the upload)
                ▼
BackupMemoryPhoto (unique per photo, no overlap, 5 tries, backoff 1m/5m/15m/60m, timeout 75s)
   backup copy already matches DB checksum?  ── yes ──► backup_status=verified
   no ─► primary matches DB checksum? ── no ──► backup_status=failed (never copy a corrupt primary)
   yes ─► stream primary → backup (versioned bucket: never destroys an earlier copy)
        ─► re-hash backup == DB checksum? ── no ──► throw → retry
        ─► yes ──► backup_status=verified, backup_verified_at=now()
retries exhausted ──► backup_status=failed (degraded), error logged for alerting
photos:backup-pending (every 10 min) re-dispatches `pending` rows idle > 15 min
```

**Two independent status columns.** `status` tracks the upload (`pending → uploading → verified | failed`). `backup_status` tracks the backup copy (`null → pending → verified | failed`). `MemoryPhoto::protectionStatus()` derives the user-facing value from both:

| status | backup_status | protectionStatus |
|---|---|---|
| pending / uploading | – | `pending_upload` |
| failed | – | `failed` |
| verified | pending | `backup_pending` |
| verified | failed | `degraded` |
| verified | verified | `protected` |

The backup columns are not mass-assignable. Only server code (`forceFill`) writes them.

**Race handling**

| Case | Handling |
|---|---|
| A job runs twice | The existing verified copy is recognised and nothing is rewritten |
| Two workers | `ShouldBeUnique` (one queued job per photo) plus `WithoutOverlapping` (one running) |
| A worker dies mid-job | Redis `retry_after` (90s) is greater than `timeout` (75s), so the job is retried. The copy is re-verified, never trusted blindly |
| The sweeper during backoff | The unique lock is held through backoff, so the sweeper cannot add retry budgets |
| A row changed during the copy | The final update only matches a row with the same `checksum` |
| The user deletes during a backup | The backup still completes. Trashed photos keep their backup until retention (STEP 8) |

`backup_error` holds the exception class and message for operators. Storage SDK messages include the internal endpoint and key, but no credentials. It must never be returned by the user-facing API.

Not yet covered: operators cannot yet retry a `failed` backup except by resetting it to `pending` (STEP 11/13). (Repair: STEP 7. Delete no longer touches objects: STEP 8.)

## 10. When a photo is `protected` (STEP 5)

A photo is `protected` **only** when every condition holds. `MemoryPhoto::protectionStatus()` evaluates them on every read. The value is never stored and never accepted from a request.

| # | Condition | Evidence | Enforced by |
|---|---|---|---|
| 1 | The primary object is stored | `status = verified` | `MemoryPhotoService::complete()` |
| 2 | The primary passes integrity | Server SHA-256 of the stored bytes equals `checksum` | `complete()` (`hash_equals`) |
| 3 | The backup object is stored | `backup_status = verified` | `BackupMemoryPhoto` |
| 4 | The backup passes integrity | Server SHA-256 of the backup bytes equals the same `checksum` | `BackupMemoryPhoto::backupMatches()` |
| 5 | The metadata needed for decryption is recorded | `checksum`, `encryption_version`, `key_id`, `nonce`, `mac` are non-empty | `hasDecryptionMetadata()`, checked in `complete()` and in `protectionStatus()` |
| 6 | Both copies can be found | The same `storage_key` on both stores. `storage_key` is set by the server and never accepted from clients | `createUploadSession()` |
| – | Not deleted | `deleted_at` is null | `protectionStatus()` returns `deleted` |

Otherwise the status is `pending_upload`, `failed`, `backup_pending` (only the primary is verified), `degraded` (backup failed, or metadata incomplete), or `deleted`. STEP 7 adds integrity and repair states.

### Checksum versus decryptability

A matching SHA-256 proves the stored bytes are the bytes the client produced. On its own, it does not prove those bytes decrypt. We close that gap without re-downloading and without the server ever seeing plaintext:

1. **On the device, before upload:** `PhotoEncryptionService.verifyRoundTrip()` decrypts the fresh ciphertext with the Couple Key and compares the result with the original bytes. A mismatch aborts the upload (`encryptionFailed`), and nothing is sent.
2. **The checksum comes from that same verified ciphertext**, and the server records it before upload.
3. **On the server:** the primary and the backup are each proven byte-identical to it (conditions 2 and 4).

So each copy of a `protected` photo is decryptable **with the Couple Key that existed at upload time**. Every view also re-checks the checksum and the GCM tag on the client (`getDecryptedPhotoBytes`).

What `protected` does **not** promise:

- **That a key is still available.** If every device and the Recovery Key are lost, a `protected` photo is still unreadable (failure G). Key availability is a client-side state (`CoupleKeyUnavailableException`) and is shown separately from storage health.
- **That nothing has changed since the last check.** Corruption after verification is detected by the scheduled integrity check (STEP 6), not by this status.

## 11. Integrity verification (STEP 6)

Every check computes SHA-256 over the stored bytes and compares it with `memory_photos.checksum`, plus `encrypted_size` where it is set. The reference is always the DB value. Provider ETags and checksums read from the object are never trusted. All checks go through `PhotoStorage::checkIntegrity()`, which returns `ok`, `mismatch`, or `missing`, and **throws** when the store cannot be reached.

| Mode | When | Where | Writes |
|---|---|---|---|
| Upload | `complete()` | Server, primary | `status=verified` |
| Backup | After each copy | `BackupMemoryPhoto`, both copies | `backup_status`, `*_integrity=ok`, `integrity_checked_at` |
| Scheduled | `photos:verify-integrity`, hourly, up to `--limit=500` photos older than `--days=7`, never-checked first | `VerifyMemoryPhotoIntegrity`, primary plus a verified backup | `primary_integrity`, `backup_integrity`, `integrity_checked_at` |
| Restore | After every repair (STEP 7) | Repair job | – |
| Client | Every view, before display | Flutter: checksum plus the AES-GCM tag | Nothing server-side |

**Rules**

- **Unreachable is not missing.** `PhotoObjectMissingException` is thrown only when the store answered "not found". A network or credentials error throws something else: the check is retried and **no column changes** (failure A).
- **Detection never modifies objects.** A `mismatch` or `missing` copy is left exactly as it is for repair to handle. A good copy is never touched.
- **A backup still being written** (`backup_status != verified`) is not checked. Its own job verifies it.
- **Trashed photos are checked too**, because they must stay restorable during retention.
- **Any `mismatch` or `missing` copy makes the photo `degraded`**, whatever the backup job recorded earlier. A warning with `photo_id` and the result is logged (no keys or paths); STEP 11 turns it into an alert.
- **`checksum` is immutable once `verified`.** The model throws on change, so a bug cannot re-baseline corrupt bytes as healthy. This guard is app-level only: raw SQL bypasses it. The DB backup (STEP 9) is the protection against that.

**Cost.** Each scheduled check reads every byte of both copies, so egress is about (primary + backup size) per `--days` period. Tune `--limit` and `--days` in STEP 16.

**Not covered:** a client that hits a GCM or checksum failure on view does not report it to the server yet. That could become a reporting endpoint in STEP 13.

## 12. Repair and self-healing (STEP 7)

```
VerifyMemoryPhotoIntegrity finds a bad copy ─┐
BackupMemoryPhoto finds a bad primary ───────┴─► repair_status=pending (protectionStatus: restoring)
                                                  │  dispatch RepairMemoryPhoto (unique; shares a per-photo lock with backup)
                                                  ▼
             re-hash BOTH copies now against the DB checksum (an unreachable store throws → retry, nothing written)
                    │
   primary ok and backup ok/not-yet-expected ──► skipped, repair_status=null
   bad copy, other copy ok ─► stream good → bad (same storage_key; versioned bucket keeps the bad bytes)
                           ─► re-hash the restored copy ── ok ──► succeeded, repair_status=null
                                                       └─ not ok ─► throw → retry (3 tries) → repair_status=failed
   no copy is ok ─► nothing written, metadata kept, repair_status=failed, Log::critical
```

- **Single object, single direction per run.** It is either backup → primary or primary → backup, the same code both ways.
- **The source is re-verified immediately before use.** A recorded `ok` from an earlier check is not trusted.
- **No temp key.** The bucket is versioned, an S3 PUT is atomic, and the copy being replaced is already known bad. The replaced bytes survive as a noncurrent version. In production this **requires versioning on the primary**. Without it, add a temp-key-then-promote step.
- **The restored copy is re-hashed before anything is marked healthy.**
- **Every outcome is written to `photo_storage_audits`**: `succeeded`, `skipped`, or `failed`, with an actor (`system`, or `user:{id}` once admins can trigger repairs in STEP 11). The audit survives photo purge (`nullOnDelete`).
- **After the primary is restored**, a backup that had given up (`backup_status=failed` because the primary was bad) is set back to `pending`. The pending sweeper retries it.
- **Lost repair jobs**: `photos:verify-integrity` re-dispatches `repair_status=pending` rows idle for more than 30 minutes.
- **`repair_status=failed` is terminal until an operator acts** (STEP 11). This includes a store that stayed unreachable for every retry.
- **No rate limit.** Repair only ever writes bytes that hash to the DB checksum, so it cannot spread garbage. A mass-mismatch event is an alerting concern (STEP 11).

### Read fallback

`GET /memory-photos/{photo}/content` serves the primary unless it is known bad or the read throws. In that case it serves the verified backup (identical ciphertext; the client still checks GCM). If neither copy is readable, it returns `503` with a plain message and no internal details.

Dev verification (2026-10-24, real SeaweedFS + Redis worker): an out-of-band corrupted primary was detected (`mismatch`), repaired from the backup in 7 s, and re-verified. The 8-byte corrupt version is still listed as a noncurrent version in `photos-primary`.


## 13. Versioning, soft delete, and retention (STEP 8)

```
user deletes photo (or its memory)
   │  row: deleted_at=now      objects: untouched      audit: trash
   ▼
TRASH ── restorable by either partner for trash_retention_days (30) ──► POST /memory-photos/{id}/restore
   │                                                                      re-hash primary; bad → repair queued
   ▼ photos:purge (daily 03:30) → PurgeMemoryPhoto
STAGE 1  claim primary_purged_at (atomic) → delete primary object        audit: purge_primary
   │      backup copy + metadata kept for backup_retention_days (30)
   ▼
STAGE 2  delete primary again (idempotent) + backup object → row force-deleted   audit: purge_backup
   │
   ▼ both buckets: the delete is only a delete marker; the bytes become a
     noncurrent version and expire by lifecycle after 30 days
```

Total time from a user delete until the last bytes are gone: trash 30 d + backup retention 30 d + noncurrent expiry 30 d ≈ **90 days** (all configurable: `PHOTOS_TRASH_RETENTION_DAYS`, `PHOTOS_BACKUP_RETENTION_DAYS`, and the bucket lifecycle rule).

### Rules

- **A user delete never touches an object.** `MemoryPhotoService::delete()` only soft-deletes the row and writes a `trash` audit row. Deleting a memory soft-deletes it and trashes all its photos in one transaction.
- **Restore** (`POST /memory-photos/{photo}/restore`): any member of the couple, only while `deleted_at` is within the trash retention, the photo was `verified`, the primary is not purged, and the memory itself is not deleted. A restored photo's primary is re-hashed right away. If it is bad, the photo shows `restoring` and a repair is queued (with the user as actor). If the store is unreachable, the restore still succeeds and an integrity check is queued; it is never reported as healthy without evidence.
- **Trash listing:** `GET /memories/{memory}/photos/trash` returns restorable photos with `restorable_until`.
- **Restore versus purge cannot both win.** Both are single conditional `UPDATE`s on the same row (`restore`: `deleted_at=null WHERE primary_purged_at IS NULL AND deleted_at > cutoff`; purge: `primary_purged_at=now WHERE deleted_at IS NOT NULL AND deleted_at <= cutoff AND primary_purged_at IS NULL`). PostgreSQL serialises them.
- **Purge is the only code path that deletes objects.** `PurgeMemoryPhoto` is unique per photo and shares the per-photo lock with backup and repair. A failure after the stage-1 claim leaves the primary in place; stage 2 deletes it again.
- **Purged photos are invisible to the other jobs.** Backup, verification, repair, and both sweepers skip rows with `primary_purged_at`, so a purged copy is never reported `missing` or "repaired" back into existence.
- **The backup is never deleted by a user action.** It is deleted only by stage 2, after its own retention.
- **Abandoned uploads** (`pending`, `uploading`, `failed` for more than `PHOTOS_ABANDONED_UPLOAD_HOURS`, default 24) are moved to the trash by `photos:purge` and follow the same path. They cannot be restored, because they were never verified.
- **The audit trail survives the purge** (`photo_storage_audits.memory_photo_id` becomes null).

### Hard-delete cascades (failure H)

Migration `2026_10_24_130000_add_retention_to_memory_photos`:

| Foreign key | Before | After |
|---|---|---|
| `memory_photos.memory_id` | cascade | **restrict**: a memory with photo rows cannot be hard-deleted |
| `memory_photos.uploaded_by` | cascade | **null on delete** |
| `memories.couple_id` | cascade | **restrict** |
| `memories.created_by` | cascade | **null on delete** |

Before this, deleting a user in Filament (`EditUser` → `DeleteAction`) silently deleted every memory they created and every photo row in them.

### Versioning and lifecycle

- Both buckets are versioned. `docker/storage/init.sh` now also sets a lifecycle rule `expire-noncurrent` (30 days) on each bucket. **SeaweedFS accepted and returns the rule; that it actually expires versions after 30 days has not been observed.** The production provider must be checked for this in STEP 16.
- The app only ever issues plain deletes (delete markers). It never deletes a specific version.
- **Dev drill, 2026-11-06, real SeaweedFS:** the app credential put a 4 KB object and deleted it. The object was hidden, and its version was still listed. The operator restored that version with `copy-object ?versionId=`, and its SHA-256 matched the original. Duration 4 s. The probe versions were removed afterwards.

### Finding for STEP 10

A probe on 2026-11-06 showed that **the backup *app* credential can permanently delete a specific object version** (`delete-object --version-id` succeeded). The bucket has object lock enabled, but no default retention is set, so nothing is locked yet. The app code never does this, but a bug or a leaked app credential could. STEP 10 must set a default retention (or remove version delete from the app identity) and add a test proving the app credential cannot do it. **Resolved in STEP 10 (§15):** default retention is set, and `verify-immutability.sh` proves the app credentials can no longer delete versions.

### Tests

`tests/Feature/Storage/PhotoRetentionTest.php`, 17 tests:
- trash leaves both objects in place;
- trash listing and restore within retention, with primary re-verification;
- restore of a photo with a missing primary queues a repair;
- refusal after retention, for another couple, and for a photo whose memory was deleted;
- purge stage 1 and 2 timing;
- verification and repair do not resurrect purged copies;
- the restore/purge race;
- abandoned uploads are trashed, not deleted;
- user hard delete keeps memories and photos; memory hard delete is blocked;
- the purge audit survives failures.


## 14. Database backup and reconciliation (STEP 9)

**Strategy for the MVP:** a daily, encrypted, logical `pg_dump`, verified by a real restore. PITR/WAL archiving is deliberately not used yet (§7). RPO is 24 h (the daily `db:backup` at 02:00). The RTO for a DB restore was measured at seconds for dev-sized data (disaster-recovery.md §8). Production must re-measure it with real volume.

```
db:backup (daily 02:00)
  row counts of key tables ─► database_backups(status=running)
  pg_dump --format=custom ─stdout─► BackupEncryptor ─► temp file (ciphertext only)
  ─► upload to db-backups bucket (own credential) ─► download + SHA-256 compare ─► status=succeeded
db:restore-check (weekly, only where an operator identity is configured)
  download ─► SHA-256 == recorded ─► decrypt ─stdin─► pg_restore into scratch DB
  ─► counts vs. recorded, invariants ─► restore_result=passed|failed ─► drop scratch DB
db:restore --database=<new>  (disaster; refuses a non-empty target)
photos:reconcile (daily 05:00, report-only)
```

- **Encryption** (`BackupEncryptor`) uses libsodium only. Each backup gets a fresh random file key, which is sealed to the operators' X25519 public key (`crypto_box_seal`). The dump is a `secretstream` (XChaCha20-Poly1305) in 64 KiB chunks, and the last chunk is tagged FINAL. Tampering, reordering, a wrong key, or truncation all fail: unit tests cover each case, including truncation exactly at a chunk boundary.
- **The app holds only the public key.** It can create backups but never read them. The secret key (`php artisan db:backup-keygen`) lives offline with the operators. In dev it sits in `backend/docker/db-backup/dev-restore.key`, which is gitignored.
- **The plaintext dump never touches disk.** It is encrypted while it streams from `pg_dump`, and decrypted while it streams into `pg_restore`. No temp or stderr files survive a run, and a test asserts this.
- **What a backup contains:** every table. That includes couples, memories, `memory_photos` metadata with `storage_key`, `checksum`, `nonce`, `mac`, and `key_id`, the encrypted key and recovery packages, the deletion and versioning columns, and the storage audit trail. It contains **no plaintext keys**, because the server never has any.
- **Restore-check invariants:**
  - `pg_restore --exit-on-error` succeeds;
  - no photo row lacks a memory;
  - the counts of key tables are reported against the counts taken at backup time (they can differ slightly because writes happen concurrently);
  - verified photos without decryption metadata are reported as a WARNING. Dev has 2 such rows, from an early drill.
- **Retention:** the `db-backups` bucket is versioned, has object lock with 30 days default retention (§15), and expires noncurrent versions after 30 days.

**Reconciliation** (`photos:reconcile`, `PhotoReconciliationService`) compares rows with a listing of **both whole buckets**. It reports:

| Finding | Meaning | Action taken |
|---|---|---|
| `missing_primary` / `missing_backup` | A row expects a copy that is not listed | Queues an integrity check, which queues a repair |
| `orphan_primary` / `orphan_backup` | An object with no row (an upload newer than a restored dump, or an old test object) | Report only. Never deleted; without the row it cannot be decrypted anyway |
| `unfinished_uploads` | Not verified, older than 24 h, not yet trashed | Report (the purge trashes them) |
| `stale_backups` | Backup pending for more than 1 h | Report (the sweeper retries) |

On dev it immediately found 2 real orphan uploads (`couples/61/...`) and a smoke-test object. It deleted nothing.

Tests: `BackupEncryptorTest` (5), `DatabaseBackupTest` (7, real `pg_dump`/`pg_restore`), `PhotoReconciliationTest` (2), `DatabaseRestoreDrillTest` (scenario F).

## 15. Backup isolation and immutability (STEP 10)

| Control | Dev implementation | Verified |
|---|---|---|
| Separate credentials | The primary app identity, the backup app identity, and the db-backup identity are each limited to their own bucket. Operator identities are never given to the app | `verify-immutability.sh` (cross-bucket writes denied) |
| The app cannot delete backups | Default object lock retention of **GOVERNANCE 30 days** on `photos-backup` and `db-backups` | App version-delete denied. Bypass-governance denied. Shortening retention denied. Changing the lock config denied. Bucket delete denied |
| A plain delete is harmless | Versioned bucket: delete marker only | The version is still listed after an app delete |
| Audit of destructive operations | `photo_storage_audits`: trash, restore, purge_primary, purge_backup, repair, reconcile, admin_* | Tests |
| Transport and storage encryption | All content is client-side encrypted (photos) or sealed (DB dumps) before it leaves the app | DR drill: no plaintext in any store |
| No backup credentials in Flutter | The app only talks to `/api/v1` | By design (no storage SDK in the Flutter code) |

Run it: `docker compose run --rm -v <abs path>/backend/docker/storage/verify-immutability.sh:/verify.sh:ro --entrypoint sh storage_init /verify.sh`. Result 2026-11-06: **12/12 PASS**.

**Limits, stated honestly**

- **The lock lasts 30 days from when each version is written.** After that, a version is unlocked, and SeaweedFS's coarse `Write` action would again let the backup app identity delete it (the STEP 8 probe proved this with an unlocked version). In production:
  - give the backup app identity **no `s3:DeleteObjectVersion` / `s3:BypassGovernanceRetention`** (S3, R2, and B2 all support this granularity; SeaweedFS does not), and
  - use **COMPLIANCE** mode on the backup bucket.
- Objects written before the default retention was set (older dev objects) are not locked.
- GOVERNANCE lets the operator credential bypass the lock. That is useful in dev and is exactly why production should use COMPLIANCE plus split custody of the operator credential.

## 16. Monitoring and alerting (STEP 11)

`StorageHealthService` is the single source of metrics. Counts come from one SQL `CASE` (`MemoryPhoto::protectionStatusSql()`), which a test keeps identical to `protectionStatus()` across all 3,456 state combinations.

**Filament** (navigation group *Storage*; admins only; metadata only):
- **Photo storage:** a per-photo table with protection, upload, backup, and integrity status, repair status, size, version, key ID, checksum, and backup error, plus the health widget. Actions: *Retry backup*, *Run integrity check*, *Request repair*. Each one asks for confirmation, is admin-only, only queues the normal job, and writes an audit row `admin_*` with `user:{id}`. There is no view, download, edit, or delete page (they return 404).
- **Database backups:** history with size, SHA-256, restore-check result, and detail. No download.
- **Storage audit log:** append-only trail with filters.
- **Widget:** alerts; protected / total; backing up and restoring; degraded, checksum mismatch, and needs-operator counts; repairs in the last 7 days; DB backup age and the last restore check; storage used (primary, backup, DB dump); queue size and failed jobs; trash.

**Alerts** (`storage:alerts`, every 15 min). Each alert is written to the `alerts` log channel (`storage/logs/alerts-*.log`; add `slack` through `ALERT_LOG_CHANNELS`). It is re-sent at most every 6 h while active, and a `Resolved:` line is written when it clears.

| Code | Level | Condition |
|---|---|---|
| `repair_failed` | critical | Any photo with no verified copy |
| `integrity_mismatch` | critical | Any copy whose checksum does not match |
| `primary_unreachable` / `backup_unreachable` | critical | A listing call to the store fails |
| `db_backup_missing` / `db_backup_stale` | critical | No backup, or the newest is older than 26 h |
| `db_restore_failed` | critical | The last restore check failed |
| `backup_pending` | warning | A backup pending for more than 60 min |
| `degraded` | warning | Any degraded photo |
| `db_restore_untested` | warning | A backup exists but has never been restore-checked |
| `failed_jobs` / `queue_backlog` | warning | Failed jobs exist, or the queue size is above 500 |

Not implemented: capacity-almost-full alerts (SeaweedFS has no quota; use the provider's billing/quota alerts in production), and cost estimates in the dashboard (§19).

## 17. User-facing protection status and API (STEP 12–13)

| Server status | User sees | Meaning |
|---|---|---|
| `protected` | *Protected* (no badge) | Both copies verified, metadata complete |
| `backup_pending` | *Backing up* | Only the primary is verified so far |
| `restoring` | *Restoring* | A bad copy was found; repair is running |
| `degraded` | *Needs attention* | A copy or metadata is missing, or the backup failed |
| `failed` | *Upload failed* | The upload never verified. The photo is still on the phone; retry it |
| `pending_upload` | *Uploading* | |

**API changes** (all behind `auth:sanctum` and couple membership):

| Endpoint | Purpose |
|---|---|
| `GET /api/v1/memories/protection` | The couple's summary: photos, protected, backing_up, restoring, needs_attention, uploading, upload_failed, overall `state`, `last_integrity_check_at`, `last_verified_backup_at` |
| `GET /memories/{memory}/photos/trash`, `POST /memory-photos/{photo}/restore` | STEP 8 |
| `protection_status`, `restorable_until` on every photo resource | Per-photo state |

Decisions:
- **No user-facing `retry-backup`.** Backups retry automatically with backoff, and an admin action exists for the rest. A user could only add load.
- **No user `protection-status` endpoint per photo.** It is already in the photo resource.
- Admin endpoints live in Filament (web guard plus `is_admin`), not in `/api/v1`.

The user API never returns `storage_key`, `backup_error`, integrity, or repair columns. A test also proves that a client sending `status`, `backup_status`, `primary_integrity`, or `protection_status` cannot change them. `state=protected` is returned only when every stored photo is protected.

**Flutter** (`memory_protection_card.dart`):
- a shield button on *Our Memories* opens **Memory Protection ❤️**, with counts, the last integrity check, and the last verified backup. If the server cannot be reached, it says so and never shows a reassuring default;
- the photo grid shows a small badge for *Backing up*, *Restoring*, or *Needs attention*;
- delete now says the photo can be restored for 30 days, offers *Urungkan* (undo), and the memory screen has *Recently deleted* with *Pulihkan* (restore);
- `uploaded_by` is nullable (a deleted uploader no longer crashes parsing).

## 18. Failure-injection tests (STEP 14)

`tests/Feature/Storage/FailureInjectionTest.php` (A–E, G–J) and `DatabaseRestoreDrillTest.php` (F). All pass.

| Test | What is injected | Proven |
|---|---|---|
| A | Primary `putObject` throws during upload | 422 response, `status=failed`, summary shows `upload_failed` / `needs_attention`, never protected |
| B | Backup `putObject` throws | The job throws (so it is retried) with backoff 1m/5m/15m/60m and 5 tries; `backup_pending` → `degraded` after the last try; primary intact; error logged |
| C | Primary bytes corrupted | Detected, verified backup restored, re-hashed, `protected`, audit `repair succeeded` |
| D | Backup bytes corrupted | Primary untouched; backup marked mismatch; warning logged; `integrity_mismatch` alert; repair goes primary → backup only |
| E | Both copies corrupted | Nothing written, metadata unchanged, `repair_status=failed`, `degraded`, `Log::critical`, `repair_failed` alert |
| F | DB lost after backup; one upload after the backup | Encrypted dump restored; every photo row from backup time found with its nonce and MAC; reconciliation clean; the late upload reported as an orphan, not deleted |
| G | User deletes while the backup is queued | Backup completes but the photo shows `deleted`, not `protected`; not purged early; restorable; `protected` after restore |
| H | Worker died after copying | Rerun twice: no `putObject`, object unchanged, one row, `protected` |
| I | Backup store unreachable for every call | Primary kept, `degraded` with the error recorded, `backup_unreachable` alert, users still get the photo |
| J | Couple has no key (key loss) | Storage stays `protected`, no repair triggered, the server returns identical ciphertext (nothing to decrypt with). The client reports `CoupleKeyUnavailableException`, not corruption |

## 19. Cost and capacity review (STEP 16)

No provider is chosen yet (§7). The numbers below are **capacity and traffic**, not prices. Multiply them by a provider's quoted unit prices when budget and reliability needs are clear. Do not take any figure here as a quote.

**Assumptions** (replace them with measured values from the Filament widget once there is real traffic):
- Average ciphertext per photo: **0.8 MB**. Photos are resized to at most 2048 px and re-encoded as JPEG q85 before encryption, and AES-GCM adds only 16 bytes. Dev data is not representative (the drill used 640×480 test images, about 29 KB). Measure `ciphertext_bytes / photos`.
- There are no thumbnails or originals stored separately. There is one object per photo, and nothing can be regenerated on the server (it cannot decrypt), so **every byte must be backed up**.
- Deletes: assume 5 % of photos are deleted. Each deleted photo is kept about 90 days in total (30 d trash + 30 d backup retention + 30 d noncurrent expiry).
- DB dump: about 1 KB per photo row including indexes. Daily dumps, 30 kept.

| Scale | Photos | Primary | Backup | Versions/trash overhead (~5 %) | DB dumps (30 kept) | **Total stored** |
|---|---|---|---|---|---|---|
| S: 100 couples × 500 | 50 k | 40 GB | 40 GB | ~4 GB | ~1.5 GB | **≈ 86 GB** |
| M: 1 k couples × 1 000 | 1 M | 800 GB | 800 GB | ~80 GB | ~30 GB | **≈ 1.7 TB** |
| L: 10 k couples × 2 000 | 20 M | 16 TB | 16 TB | ~1.6 TB | ~600 GB | **≈ 34 TB** |

**Traffic per month** (excluding user views):

| Item | Formula | S | M | L |
|---|---|---|---|---|
| Upload and backup (10 % growth/month) | 3 reads + 2 writes per new photo | 4 GB writes, 12 GB reads | 80 / 240 GB | 1.6 / 4.8 TB |
| **Integrity sweep** (both copies every 7 days) | 4.3 × (primary + backup) reads | **344 GB** | **6.9 TB** | **138 TB** |
| Weekly restore check | 4.3 × dump size | < 1 GB | 4 GB | 86 GB |

**Findings (actual bottlenecks, not premature optimisation):**

1. **The integrity sweep dominates traffic.** If the backup is at another provider (as §15 requires), its share is **egress**, which is usually the most expensive line item. Before launch, either:
   - verify the backup less often than the primary (for example 30 days instead of 7), or
   - store our SHA-256 as a provider-side checksum (`x-amz-checksum-sha256`) and let the provider attest it on GET or HEAD, keeping our full re-hash for samples and repairs.
2. **The sweep cannot reach its own target at scale M.** `--limit=500` hourly is 84 k checks a week, and 1 M photos would take about 12 weeks per full pass. The limit has to scale with photo count. Throughput was not load-tested.
3. **Backups double storage**, as expected. Versioning and trash add about 5 % under these assumptions. Incremental backup does not help for immutable photo objects, because each one is written once.
4. **The DB is small** relative to photos even at L (about 20 GB per dump). Daily logical dumps stay practical. Revisit PITR only if the RPO must drop below 24 h.
5. **Restore egress** for a full primary rebuild equals the whole backup size: 0.8 TB at M, 16 TB at L. Include this in the provider choice as a one-time disaster cost.

**Cost formula** to fill in once providers are quoted: `monthly ≈ GB_primary × p_primary + GB_backup × p_backup + egress_GB × p_egress + (PUT/GET ops ÷ 1000) × p_ops + DB_dump_GB × p_backup`.

## 20. Phase 6 final audit (STEP 17)

Evidence as of 2026-11-06: backend full suite passing, Flutter 144 tests passing, `verify-immutability.sh` 12/12, DR drill 23/23 (disaster-recovery.md §8).

| Area | Item | Status | Evidence |
|---|---|---|---|
| Storage | Private primary storage | ✅ | Private S3 buckets, `throw`, content only via an authorised streaming endpoint |
| | Independent backup | ⚠️ dev only | Separate instance, bucket, and credential; **same Docker host in dev**. A second provider or account is required before production (§8, §19) |
| | Backup holds ciphertext only | ✅ | Byte-for-byte copy; drill plaintext scan |
| | Idempotent upload/backup workflow | ✅ | Test H, `BackupMemoryPhotoTest` |
| | Retry with bounded backoff | ✅ | Test B (5 tries, 1m→60m), sweepers |
| | Versioning and retention as designed | ✅ / ⚠️ | Versioning, trash, purge, and object lock tested. The lifecycle rule is accepted by SeaweedFS but its expiry has not been observed yet |
| Integrity | SHA-256 of ciphertext against the DB reference | ✅ | §11 |
| | Primary, backup, scheduled, and restore verification | ✅ | Tests C–E, drill |
| | Repair workflow | ✅ | `RepairMemoryPhotoTest`, drill |
| Database | Automated PostgreSQL backup | ✅ | `db:backup` daily; dev backups #1–#2 |
| | Offsite backup | ⚠️ dev only | Stored in the backup store, which is on the same host in dev |
| | Retention policy | ✅ | Object lock 30 d + noncurrent expiry 30 d |
| | Recovery procedure | ✅ | `db:restore`, `db:restore-check`, runbook, drill |
| | Metadata reconciliation | ✅ | `photos:reconcile`, test F |
| Security | No plaintext photo on the server | ✅ | Drill scan, `EncryptionSecurityTest` |
| | No plaintext keys in backups | ✅ | Drill DB scan (couple key absent); DB dumps sealed to an offline key |
| | Backup credentials isolated | ✅ | `verify-immutability.sh` |
| | Private storage access | ✅ | Phase 4/5 tests |
| | Admin actions audited | ✅ | `StorageMonitoringTest` |
| | Immutable backup protection tested | ✅ (30 d) | 12/12. Production needs IAM without version-delete plus COMPLIANCE (§15) |
| UX | Accurate protection status | ✅ | SQL/PHP equivalence test, API tests |
| | Pending backup shown correctly | ✅ | API and widget tests |
| | Failed upload not treated as success | ✅ | Test A; Phase 5 upload flow |
| | Clear error states, retry where safe | ✅ | Upload retry (Phase 5), undo and restore from trash |
| Operations | Monitoring and alerting | ✅ | Filament, `storage:alerts` |
| | Failure-injection tests | ✅ | A–J |
| | DR drill | ✅ | disaster-recovery.md §8 |
| | Cost and capacity reviewed | ✅ | §19 |

**Open items that do not block Phase 6 but block a production launch:**
1. Choose providers and use a real second failure domain for the backup and DB dumps, with IAM that has no version-delete, COMPLIANCE lock, and split operator custody.
2. Repeat the DR drill there, at realistic size, run by a second operator.
3. Fix the integrity-sweep cost and throughput (§19, findings 1–2).
4. Route the `alerts` channel to a pager or Slack.
5. Observe the lifecycle expiry once (30 d) on the chosen provider.
6. Not yet built: client-reported GCM/checksum failures to the server (§11), and capacity alerts.

The Flutter UI changes were verified with widget tests and `flutter analyze`, not on a physical device.
