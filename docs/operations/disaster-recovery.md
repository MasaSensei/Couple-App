# Disaster recovery plan

Photo-level design and the Phase 6 recovery drill:
[docs/storage/disaster-recovery.md](../storage/disaster-recovery.md). This page is
the whole-system plan. **Database recovery and photo recovery are separate
processes**, and restored ciphertext is only useful to users who still hold a
valid key (a device with the Couple Key, the partner's device, or their Recovery Key).

## 1. Objectives

Chosen for a small team, one region, a single application host and the
cost model's budget — not aspirational numbers.

| Asset | RPO (max data loss) | RTO (max downtime) | Basis |
|---|---|---|---|
| Database (now: daily encrypted dump) | **24 h** | **4 h** | dump 02:00; restore measured in seconds at dev size — re-measure on staging with real volume |
| Database (target: managed PG with PITR) | **5 min** | **2 h** | provider PITR |
| Photos, backup verified | **0** | read access: 4 h (repair from backup, throughput-bound) | two independent stores |
| Photos uploaded but backup not yet verified | up to backup lag (normally < 1 min, alert at 60 min) | — | phone keeps the original until upload is verified; after that the user may delete it |
| Redis | jobs in flight (AOF fsync 1 s); all re-derivable by sweepers | 15 min | `photos:backup-pending`, `billing:retry-webhooks` |
| Whole service (host lost) | as DB | **1 working day** (≤ 1,000 couples) | rebuild from Git + registry + secret store |

## 2. Roles & credentials

| Role | Who | Holds |
|---|---|---|
| Owner | project owner | approves production deploys, destructive actions, user communication |
| Operator / on-call | developer on rotation | host SSH (VPN), registry, env files via secret store, Filament admin (MFA) |
| Key custodians (2 people) | owner + one operator | **DB backup secret key** (offline: password manager + sealed paper copy), storage operator credentials (bucket admin, object-lock governance) |

Credentials needed for recovery, stored in the secret store with an offline
copy: host provider account, DNS, registry, `production.env`, storage provider
A & B root/operator accounts, DB backup secret key, store consoles (Play/App Store).

## 3. Scenarios

| # | Scenario | Detect | Recover | RPO / RTO |
|---|---|---|---|---|
| 1 | **App host failure** (VM dead, disk intact) | uptime monitor, heartbeats | restart/recreate VM; `deploy.sh <env> <current-tag>` | 0 / 1 h |
| 2 | **PostgreSQL failure / data loss** | `database_down`, readiness 503 | stop writers → `db:restore` latest dump into new DB → switch → reconcile ([database.md §4](database.md#4-restore)); tell couples to re-upload photos newer than the dump | 24 h / 4 h |
| 3 | **Redis failure** | `redis_down`, queue heartbeat | restart (AOF) or recreate empty; run sweepers | ~0 / 15 min |
| 4 | **Primary storage failure** | `primary_unreachable`, readiness | provider outage: wait (backups continue to queue). Data loss at provider: new bucket → set env → `photos:reconcile` → repair jobs copy from backup | 0 / hours (volume-bound) |
| 5 | **Backup storage failure** | `backup_unreachable` | photos show "backing up" (never falsely protected); if data lost: new bucket (object lock) → `photos:backup-pending --older-than=0` re-copies everything | 0 / days in background, no user impact |
| 6 | **Accidental deletion** | user report / audit log | user: trash restore ≤ 30 days; object deleted by operator: bucket versioning (30 days) restore; rows deleted: restore dump into scratch DB, copy rows back | 0–24 h / hours |
| 7 | **Corrupted photo object** | weekly integrity check, `integrity_mismatch` | automatic repair from the other copy (verified in drill C) | 0 / minutes |
| 8 | **Compromised app credentials** | unusual access, alerts | rotate all secrets ([runbooks.md](runbooks.md#secret-rotation)); backup buckets are object-locked (app key cannot delete versions); review logs; breach procedure | — / hours |
| 9 | **Lost encryption key** | user report | user: partner device re-shares, or Recovery Key restores; **none of these → photos are unrecoverable by design**. Operator lost the DB backup secret key: backups unreadable → generate a new key pair immediately, take a new backup; that is why there are 2 custodians | user: by design / operator: next backup |
| 10 | **Complete infrastructure outage** (host + provider A) | everything red | new host from Git + images + env; restore DB from the backup store; new primary bucket; reconcile + repair from backup; DNS switch | 24 h / 1 working day |

## 4. Drills

Never on production. Two complementary drills:

- **Recovery drill** (Phase 6, `storage:dr-drill prepare|verify`): primary lost + DB restored from dump → every photo repaired from backup and decrypted byte-identical. Log: docs/storage/disaster-recovery.md §8.
- **Failure drill** (Phase 9, `deploy/drills/storage-failure-drill.sh`): stops/corrupts real services of the local stack and checks behaviour. Log below.

Run both quarterly on staging and after every storage/backup change.

### Failure drill log

**2026-11-07, dev stack (Docker Desktop on Windows, 2× SeaweedFS, PostgreSQL 17, Redis 7, live queue worker), operator: Claude Code session.** Run 3 (runs 1–2 exposed script bugs, see below): **19 passed, 2 failed**, 13:31–13:43 UTC.

| # | Scenario | Result |
|---|---|---|
| A | Backup store down | PASS — upload verified on primary; photo `backup_pending`, **not** protected; readiness 503 (11.7 s); alert `backup_unreachable`; protected after the store returned |
| B | Primary store down | PASS — readiness 503 (17.2 s); alert `primary_unreachable`; upload not completed, verified count unchanged |
| C | Corrupted primary object | PASS — `mismatch` detected, status `restoring` (not protected), repaired from backup, SHA-256 equal to the original, protected. (Run 2: the live worker auto-repaired within seconds — audit `repair succeeded` 13:29:00 — before the script could observe the intermediate state; the drill now pauses the worker for C) |
| D | Queue worker down | PASS — job waited in Redis; drained after restart; queue heartbeat 21 s |
| E | Database down | **FAIL** — liveness 200 OK, but readiness and an API call did not answer within 20 s (expected 503 / JSON 500). Readiness returned to 200 after the DB came back. Cause: DNS lookup of the stopped `postgres` container is slow in Docker and Laravel reconnects once. **Open**: affects the production compose too (same hostname scheme). Mitigations to test: managed PostgreSQL (always-resolvable host), `DB_HOST` as a static IP on the internal network, or a resolver timeout. |
| F | Restore from backup | PASS — encrypted dump created; restore-check into scratch DB passed |

Timings over 10 s in A/B/E are dominated by Docker Desktop DNS for stopped containers; re-measure on a Linux staging host.

Script bugs found and fixed while building the drill: Redis queue key prefix, `prepare` exit code meaning, PHP quoting inside shell, and editing the script while it ran (sh reads scripts incrementally — run drills from a copy).
