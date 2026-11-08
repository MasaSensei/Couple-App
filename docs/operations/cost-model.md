# Operational cost model

Estimates for planning, **not quotes**. Unit prices are list-price assumptions
(late 2026) to be re-checked with the chosen providers; currency USD. Infrastructure
cost is kept separate from subscription revenue (§4).

## 1. Usage assumptions

| Assumption | Value | Basis |
|---|---|---|
| Stored photo size | 0.6 MB | app resizes to max 2048 px, JPEG q85, strips metadata; +28 B GCM overhead |
| Photos per couple per year | light 150 · typical 600 · heavy 2,400 | includes Photo Booth prints |
| Couple mix | 50 % light · 40 % typical · 10 % heavy | not everyone uses max capacity |
| → average | **555 photos ≈ 0.33 GB per couple per year** | |
| Backup copy | 1 × primary (same ciphertext) + 30-day versions (~+5 %) | Phase 6 design |
| Downloads | each photo fetched ~6×/year (new devices, cache misses) | app caches decrypted thumbnails poorly today → conservative |
| API calls | 2 users × 80 requests/day | sessions, lists, comments, refresh |
| DB size | ~5 MB per couple incl. indexes | text rows only; no photos |
| Peak traffic | 5 × average | evenings / holidays |

## 2. Volume projection (end of year 1; storage grows every year)

| Couples | Primary | Backup | Egress / month | DB | Requests / month | Avg / peak req/s |
|---:|---:|---:|---:|---:|---:|---:|
| 100 | 33 GB | 33 GB | 16 GB | 0.5 GB | 0.5 M | 0.2 / 1 |
| 1,000 | 325 GB | 325 GB | 163 GB | 5 GB | 4.8 M | 1.9 / 10 |
| 10,000 | 3.3 TB | 3.3 TB | 1.6 TB | 50 GB | 48 M | 19 / 95 |
| 100,000 | 32.5 TB | 32.5 TB | 16 TB | 500 GB | 480 M | 185 / 930 |

Year 2 roughly doubles storage (photos are kept; nothing expires with a plan).

## 3. Monthly infrastructure cost (year-1 volumes)

Assumed providers for the estimate: primary on an S3-compatible store with free
egress (R2-class, ~$0.015/GB-month), backup on a low-cost store (B2-class,
~$0.006/GB-month, egress only on restore), VPS-class compute.

| Item | 100 | 1,000 | 10,000 | 100,000 |
|---|---:|---:|---:|---:|
| App + queue + scheduler hosting | 1 VPS 4 vCPU/8 GB: $20 | same: $20 | 2–3 app VPS + LB: $90 | 6–8 app nodes + LB: $500 |
| PostgreSQL | in compose: $0 | managed small + PITR: $30 | managed 2 vCPU/8 GB HA: $200 | 8 vCPU/32 GB HA + replica: $1,200 |
| Redis | in compose | in compose | managed small: $25 | managed HA: $150 |
| Primary storage | $0.5 | $5 | $50 | $490 |
| Backup storage | $0.2 | $2 | $20 | $200 |
| Egress | $0 (free egress) | $0 | $0 | $0–100 (CDN/requests) |
| Storage requests (PUT/GET) | <$1 | ~$2 | ~$15 | ~$150 |
| Monitoring / logs / crash reports | free tiers: $0 | $0–30 | $80 | $400 |
| Staging environment | $10 | $15 | $40 | $150 |
| Domain + TLS | $1.5 | $1.5 | $1.5 | $1.5 |
| Push (FCM/APNs) | $0 | $0 | $0 | $0 |
| **Total / month** | **≈ $35** | **≈ $80–110** | **≈ $520** | **≈ $3,300–3,500** |
| per couple / month | $0.35 | $0.08–0.11 | $0.05 | $0.035 |

Notes: below ~1,000 couples cost is dominated by fixed compute, not storage.
Above 10,000 the database and its HA dominate; storage grows linearly each year
(100k couples ≈ +$700/month per year of retained photos). Backup retention
(30-day versioning) adds ~5 % to backup storage.

## 4. Revenue side (kept separate)

Store fees: 15 % (Apple Small Business Program / Google's 15 % tier for the
first $1 M and for subscriptions) or 30 % otherwise; taxes/VAT on top depending
on market. For a plan priced `P` per month, net ≈ `0.85 × P` (≤ $1 M/yr).

Break-even (infra only, year 1): `paying_couples × 0.85 × P ≥ total`. Example
with a placeholder P = $3/month: 100 couples → 14 paying couples; 10,000 → 204
paying couples (2 %). Prices in the dev seeder are placeholders (Phase 8 report).

Not included: developer time, support, legal (privacy policy, counsel), Apple
Developer Program ($99/yr), Google Play one-time fee ($25), penetration test and
crypto review (one-off, typically the largest early cost).

## 5. What to measure after launch

Real photos per couple, average stored size, download ratio, request rate per
DAU, DB growth per month. Replace the assumptions above with measured values
monthly (`select count(*), sum(encrypted_size) from memory_photos where status='verified'`).
