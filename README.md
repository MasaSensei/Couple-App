# Couples App ("Our Little Space")

A private space for two people: dates, memories, comments and **photos that are
encrypted on the phone before upload**, stored in two independent object
stores, with themes, an on-device Photo Booth and couple subscriptions.

> **Status (2026-11-07): Phase 9 — not production-ready.** Code, tests, production
> images and runbooks exist; real store billing, a staging/production host,
> external monitoring, signing and legal pages do not. Full assessment:
> [docs/reports/phase-9-report.md](docs/reports/phase-9-report.md).

## Stack

| Layer | Technology |
|---|---|
| App | Flutter (Android, iOS), Riverpod, Dio, GoRouter, flutter_secure_storage, `cryptography` (AES-GCM, X25519, HKDF) |
| API | Laravel 13 (PHP 8.5), Sanctum, FilamentPHP 5 (admin) |
| Data | PostgreSQL 17, Redis 7 (cache, queue, locks) |
| Storage | S3-compatible primary + independent backup (dev: 2× SeaweedFS) |
| Runtime | Docker; production: Caddy → Nginx → PHP-FPM, separate queue & scheduler containers |
| CI | GitHub Actions (`.github/workflows/backend.yml`, `flutter.yml`) |

## Repository

```
backend/            Laravel API + admin, tests, docker/ (dev image, production image, storage init)
frontend/           Flutter app + tests
deploy/             production/staging compose, Caddy, env templates, deploy & smoke scripts,
                    local image verification, failure drill, load test
docs/operations/    architecture, environments, security, monitoring, runbooks, database,
                    DR plan, account deletion, release checklists, privacy/legal, cost model
docs/security|storage|billing|appearance/   domain design docs
docs/reports/       phase reports
```

Start with [docs/operations/README.md](docs/operations/README.md).

## Local development

Requirements: Docker Desktop, Flutter (stable). No PHP on the host is needed.

```bash
cp backend/.env.example backend/.env       # then: docker compose run --rm app php artisan key:generate
docker compose up -d --build               # app :8000, postgres, redis, queue, scheduler, 2× storage
docker compose exec app php artisan migrate
```

```bash
cd frontend
flutter pub get
flutter run                                 # dev build → http://10.0.2.2:8000/api/v1 (Android emulator)
```

Release/staging builds take `--dart-define=APP_ENV=… --dart-define=API_BASE_URL=https://…`
([release checklist](docs/operations/release-checklist.md)).

## Quality checks (same as CI)

```bash
docker compose run --rm app_test php artisan test          # backend: 350+ tests (PostgreSQL)
docker compose run --rm --no-deps app_test ./vendor/bin/pint --test
docker compose run --rm --no-deps app_test composer audit
cd frontend && dart format --output=none --set-exit-if-changed lib test && flutter analyze --fatal-infos && flutter test
```

## Phases

| Phase | Scope | State |
|---|---|---|
| 1–2 | Backend & Flutter foundation, auth, couple | done |
| 3–4 | Dates, memories, comments | done |
| 5 | Client-side photo encryption, key sharing, recovery key | done (TOFU limitation documented) |
| 6 | Redundant storage, integrity, repair, retention, encrypted DB backups | done (dev stores share one host) |
| 7 | Themes, Photo Booth | done |
| 8 | Couple subscriptions & entitlements | done with **mock store only** |
| 9 | Production readiness, deployment, monitoring | in progress — see report |

## Principles

Privacy by design (the server never holds photo keys or plaintext), honest
status in the app (*Protected* only after the backup is verified), simple
architecture (modular monolith), stabilise before adding features, and never
claim a backup, restore or security property that has not been tested.

Secrets are never committed: `.env*`, `deploy/env/*.env`, keystores and key files are git-ignored.
