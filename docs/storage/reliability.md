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

Not yet covered: repair (STEP 7). Primary delete still removes the object until STEP 8. Operators cannot yet retry a `failed` backup except by resetting it to `pending` (STEP 11/13).

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
