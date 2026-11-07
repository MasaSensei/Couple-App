# Performance & scalability

## Measured (2026-11-07)

| Check | Result | How |
|---|---|---|
| N+1 queries | none on `GET /memories`, `/memories/timeline`, `/dates`, `/memories/{id}/photos` — same query count for 2 and 20 items | `tests/Feature/Performance/QueryBudgetTest.php` |
| Missing FK indexes | 11 found and added (incl. `couple_members.user_id`, read on almost every request) | DB audit, database.md |
| Request latency (single requests, production image, idle) | `/health` 14 ms in Nginx+FPM access log; `/health/ready` DB 11–22 ms, Redis 1–4 ms, stores 17–200 ms | `http.request` log + readiness details on the verify stack |
| Slow-query visibility | `log_min_duration_statement=500` in production compose | config |

## Not yet measured

- **Load test.** `deploy/loadtest/api-mix.js` (k6) is written — ramp to 50 virtual users (~2× the 10k-couple evening peak of ~95 req/s), read-heavy mix with 25 % writes, thresholds p95 < 500 ms reads / < 800 ms writes, < 1 % errors — but it has **not been run**. On the development laptop (16 GB RAM) Docker Desktop froze twice while running the dev stack, the production verify stack and builds together, so results there would describe the laptop, not the system. Run it on the staging host:
  ```bash
  docker run --rm -i --network couples-staging_edge -e BASE=http://web:8080/api/v1 \
      grafana/k6:0.57.0 run - < deploy/loadtest/api-mix.js
  ```
  Staging needs high `RATE_LIMIT_*` values for the test window only (one source IP creates all test users), then reset.
- **Concurrent uploads.** Not covered by the k6 mix (an upload needs client-side encryption + key packages). Plan: a k6 script using pre-encrypted fixture blobs and a prepared couple key, or N parallel `storage:dr-drill prepare` runs on staging. Watch PHP-FPM children (uploads hold a worker for the transfer), storage latency and the couple row lock in the quota check.
- **Queue throughput** (backup jobs/minute per worker) under an upload burst.
- **Photo Booth on device**: render/encrypt time and memory on a low-end Android phone (on-device only; server unaffected).
- **Memory usage** of PHP-FPM children under load (sizing `PHP_FPM_MAX_CHILDREN`; 60 MB/child assumed).

## Known scalability limits (fix when measurements demand it — no premature optimisation)

| Limit | When it matters | Plan |
|---|---|---|
| `/dates`, `/memories/{id}/photos`, comments not paginated | couples with hundreds of items in one list | cursor pagination, API v1 compatible (optional `cursor`) |
| Uploads stream through PHP | many concurrent uploads | pre-signed PUT URLs to object storage, server verifies checksum on `complete` |
| One app host, PG in compose | > ~1k couples or uptime SLO | managed PostgreSQL with PITR, second app host |
| No CDN for ciphertext downloads | large egress | cacheable signed URLs (ciphertext is safe to cache privately) |
