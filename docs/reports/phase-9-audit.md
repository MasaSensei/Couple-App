# Phase 9 — Audit Awal & Implementation Plan

Tanggal audit: 2026-11-07. Branch: `phase-8-subscriptions` (clean, HEAD `1c8136c`).
Dokumen ini adalah titik awal Phase 9. Semua angka di bawah berasal dari perintah yang benar-benar dijalankan saat audit.

## 1. Bukti yang dijalankan

| Pemeriksaan | Perintah | Hasil aktual |
|---|---|---|
| Backend test | `docker compose run --rm app_test php artisan test` | **314 passed (1263 assertions)**, 301 s |
| Flutter analyze | `flutter analyze` | No issues found |
| Flutter test | `flutter test` | **321 passed** |
| Code style backend | `vendor/bin/pint --test` | **±100 file gagal** (mayoritas `line_ending` CRLF, sebagian style) |
| Dependency security | `composer audit` | **15 advisory pada 9 paket** (filament MFA, livewire authz bypass, league/commonmark DoS *high*, symfony http-foundation/kernel/routing/mime, dll.) |
| Kondisi container dev | `docker compose ps -a` | **Redis mati sejak 06 Nov 15:23 (SIGTERM, bukan crash)**; `couples_queue` crash-loop **431 restart**; scheduler gagal di setiap tick |
| Backup DB terjadwal | `select … from database_backups` | Backup terakhir **06 Nov 14:19**. Jadwal `02:00` hari ini **tidak berjalan** dan **tidak ada alert yang terkirim** |

Temuan terakhir adalah bukti langsung bahwa monitoring saat ini tidak mendeteksi kegagalan infrastruktur: alert dedupe (`storage:alerts`) dan mutex `withoutOverlapping()` sama-sama bergantung pada Redis, sehingga saat Redis mati, *sistem alert ikut mati*.

## 2. Status fitur

"Terverifikasi" = dicakup test otomatis yang lulus hari ini. Belum ada uji end-to-end di perangkat fisik release build.

### 2.1 Selesai & terverifikasi (test)
- Auth register/login/logout/me, profil.
- Couple: create, join (kode & invitation token), maks. 2 anggota, otorisasi keanggotaan, cross-couple 403.
- Dates + komentar; Memories + komentar + timeline.
- Enkripsi foto client-side: AES-256-GCM, nonce acak 96-bit, AAD mengikat photo id & key slot, HKDF per foto, X25519 key wrapping per device, recovery key 256-bit; test tamper tag/ciphertext/truncation/wrong key; test pencarian kunci/plaintext di seluruh DB & storage.
- Device registration, revocation (token dicabut, re-register ditolak).
- Storage redundancy: primary + backup terpisah (dev: dua SeaweedFS), checksum, backup/repair/verify/purge jobs (unique, backoff), reconcile, trash 30 hari, status *Protected* hanya setelah backup terverifikasi.
- Backup DB terenkripsi (sealed box, kunci rahasia offline) + `db:restore-check` + `db:restore`.
- Themes (premium ditegakkan server) & Photo Booth on-device.
- Subscription: plan versioning, entitlement, kuota, lifecycle, webhook idempotent — **hanya dengan mock store**.

### 2.2 Ada tetapi belum lengkap
| Area | Kondisi aktual |
|---|---|
| Token lifecycle | Sanctum `expiration => null` → token **tidak pernah kedaluwarsa**; tidak ada refresh/rotasi. Token login baru terikat ke device hanya setelah `POST /devices`. |
| Admin (Filament) | Hanya flag `is_admin` + 3 permission billing. **Tanpa MFA**, tanpa pembatasan IP/domain, password policy default. Advisory Filament terkait MFA belum di-patch. |
| Health check | `/api/v1/health` & `/up` hanya mengembalikan 200 — tidak memeriksa DB, Redis, queue, storage. |
| Logging | Laravel default (file `single`), level `debug`, tanpa request ID, tanpa format JSON, tanpa redaksi eksplisit. |
| Alerting | `storage:alerts` → log channel `alerts` (file/Slack). Tidak ada alert queue backlog, failed jobs, scheduler heartbeat, error rate, atau dead-man's switch eksternal. |
| Scheduler | `withoutOverlapping()` ada, **`onOneServer()` tidak ada** → jika scheduler jalan di >1 instance, job ganda. |
| `ProcessPaymentWebhook` | Tanpa `$timeout`. |
| Payment | Google Play & App Store provider *fail closed* (belum ada kredensial / implementasi). |
| Storage provider | Dua bucket di host Docker yang sama — **bukan** failure domain terpisah. |
| Flutter config | `AppConfig.apiBaseUrl = 'http://10.0.2.2:8000/api/v1'` hardcoded; tidak ada flavor/dart-define. |
| Dokumentasi | README root tertinggal (masih Phase 1–3). Docs per-domain (encryption, storage, DR, billing) cukup baik. |

### 2.3 Belum diimplementasikan
- **Rate limiting auth**: `/auth/login`, `/auth/register` tidak di-throttle sama sekali (brute force / credential stuffing).
- **Password reset / lupa password**.
- **Penghapusan akun** (wajib Apple App Store Guideline 5.1.1(v) dan Google Play) & **ekspor data**.
- **Keluar dari couple**.
- **Push notification** (FCM/APNs) & **date reminders** — tidak ada sama sekali.
- **Production Docker**: image hanya `php:8.5-cli` + `php artisan serve` (development server), root user, `composer install` dengan dev deps, source di-bind-mount.
- **CI/CD**: tidak ada `.github/workflows`.
- **Security headers / HSTS / CORS config / TrustProxies**: tidak dikonfigurasi.
- **Crash reporting Flutter**.
- **Android release signing** (`buildTypes.release` tidak ada), applicationId/bundle id masih `com.example.frontend`.
- **iOS permission strings**: `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription` tidak ada di `Info.plist` → `image_picker` akan **crash di iOS**.
- Load testing, cost model, privacy policy, ToS, Data Safety / App Privacy mapping.
- Environment staging & production (belum ada host, domain, TLS).

### 2.4 Bug / risiko
| # | Severity | Temuan |
|---|---|---|
| R1 | **Critical** | Login/register tanpa rate limit. |
| R2 | **Critical** | Monitoring buta terhadap kegagalan Redis/queue/scheduler (terbukti: backup DB terlewat tanpa alert). |
| R3 | **Critical** | Tidak ada konfigurasi production; dev server + `APP_DEBUG=true` + debug log level adalah satu-satunya runtime yang ada. |
| R4 | High | Token API tanpa expiry; token yang bocor berlaku selamanya sampai logout/revoke device. |
| R5 | High | 15 advisory dependency (termasuk *high* DoS dan authz bypass Livewire yang dipakai Filament). |
| R6 | High | Postgres `5432` & Redis `6379` dipublikasikan ke host; Redis tanpa password. (Aman di dev; **tidak boleh** terbawa ke production.) |
| R7 | High | Key package tidak ditandatangani pengirim (TOFU): server jahat/terkompromi bisa memberi Couple Key palsu ke device baru → foto baru dienkripsi dengan kunci yang diketahui penyerang. Mitigasi sebagian = perbandingan fingerprint manual. **Membatasi klaim "end-to-end encryption"** di privacy policy. |
| R8 | High | Tidak ada penghapusan akun → penolakan store review. |
| R9 | Medium | Android `usesCleartextTraffic="true"` global. |
| R10 | Medium | `User::couple()` (hasOne) salah, tidak dipakai — hapus. |
| R11 | Medium | Scheduler tanpa `onOneServer()`. |
| R12 | Low | ±100 file gagal Pint (CI akan merah). |
| R13 | Info | Pembayaran produksi masih mock; tidak boleh diklaim aktif. |

## 3. Review arsitektur

Target (tetap monolith — tidak perlu microservices):

```
Flutter ──HTTPS──▶ Reverse proxy (TLS, HSTS, rate limit, body size)
                     └─▶ Nginx + PHP-FPM (Laravel API + Filament)   ×N stateless
                            ├─▶ PostgreSQL (managed, PITR)          ← SPOF utama
                            ├─▶ Redis (cache, queue, locks)        ← SPOF untuk queue/scheduler
                            ├─▶ Object storage primary (provider A, private)
                            └─▶ Object storage backup  (provider B / akun terpisah, object lock)
                     Queue worker ×N (supervisor, graceful SIGTERM)
                     Scheduler ×1 (+ onOneServer sebagai pengaman)
                     Monitoring: logs JSON + metrics + dead-man's switch eksternal
```

| Komponen | Single point of failure? | Kondisi kini | Yang diperlukan |
|---|---|---|---|
| App | Ya (1 container) | dev server | ≥2 replica di belakang proxy (bisa ditunda; restart policy + health check cukup untuk v1) |
| PostgreSQL | **Ya** | container lokal | Managed PG dengan PITR, atau container + WAL archiving. Batas koneksi: PHP-FPM tanpa pooling → `pm.max_children × replica` harus < `max_connections`; PgBouncer bila perlu. |
| Redis | **Ya** untuk queue/cache/lock | tanpa password, tanpa persistensi terjamin | Password, tidak terekspos, AOF; alert ketika down. Kegagalan Redis = upload tetap bisa (DB), tapi backup/verify tertunda → sweeper `photos:backup-pending` sudah ada sebagai safety net. |
| Storage primary/backup | Tidak (dua salinan) | satu host | Dua provider/akun nyata; timeout & retry S3 client dikonfigurasi. |
| Alerting | **Ya, dan bergantung pada Redis** | — | Heartbeat eksternal + alert yang tidak bergantung pada Redis. |

## 4. Keputusan yang dibutuhkan dari Anda

Beberapa langkah tidak bisa dikerjakan tanpa pilihan infrastruktur/akun:

1. **Hosting staging & production**: VPS + Docker Compose (paling sederhana, murah), atau platform managed (mis. managed Postgres + container host)?
2. **Object storage production**: dua provider berbeda (mis. Cloudflare R2 + Backblaze B2 / Wasabi), atau satu provider dua akun/region?
3. **Monitoring/crash reporting**: SaaS (mis. Sentry + Better Stack/Healthchecks) atau self-hosted (Prometheus + Grafana + Loki)?
4. **Scope v1**: apakah push notification & date reminders wajib untuk rilis pertama, atau ditunda?
5. **Akun**: Google Play Console, Apple Developer, domain, repository GitHub (CI akan pakai GitHub Actions di `MasaSensei/Couple-App`).

Tanpa keputusan ini, saya tetap bisa mengerjakan semua hal yang provider-agnostic (STEP 1–5, 8–10 di bawah) dan menandai bagian yang menunggu.

## 5. Implementation plan Phase 9

Satu STEP per giliran; setiap STEP: tujuan → kondisi aktual → file → risiko → implementasi → test → hasil → tunggu konfirmasi.

| STEP | Isi | Output utama | Butuh keputusan? |
|---|---|---|---|
| 0 | **Pulihkan dev env**: start Redis, pastikan queue berhenti crash-loop, jalankan `db:backup` yang terlewat, verifikasi. | Bukti container sehat & backup baru | Tidak (minta izin start container) |
| 1 | **Security hardening backend (blocker)**: rate limiter login/register/key endpoints; expiry token + rotasi/refresh + revoke semua sesi; patch dependency (`composer update` terkontrol); security headers + TrustProxies + CORS eksplisit; hapus `User::couple()`; `$timeout` webhook job. | Test baru untuk setiap kontrol | Tidak |
| 2 | **Observability dasar**: request/correlation ID middleware, log JSON ke stderr, processor redaksi (password, token, key, recovery), deep health check (`/health/ready`: DB, Redis, storage, queue lag), scheduler heartbeat. | Middleware + test redaksi | Tidak |
| 3 | **Production Docker**: multi-stage image (composer `--no-dev`, opcache, non-root), Nginx + PHP-FPM, service web/queue/scheduler terpisah, healthcheck, resource limit, logging driver, graceful stop; `docker-compose.prod.yml` + overlay staging; DB/Redis tanpa port publik, Redis password; `.env.example` per environment; migrasi sebagai one-off job. | Image ter-build & di-smoke-test lokal dengan `APP_ENV=production` | Tidak |
| 4 | **CI (GitHub Actions)**: backend (composer validate, Pint, tests dengan Postgres service, `migrate:fresh` + rollback test, `composer audit`, Docker build); Flutter (format, analyze, test, build APK; iOS di runner macOS). Commit format-only terpisah untuk Pint. | Workflow + run hijau di GitHub | Push ke GitHub (minta izin) |
| 5 | **Alerting & monitoring**: alert queue backlog / failed jobs / scheduler heartbeat / backup age / webhook failure / subscription inconsistency, jalur alert yang tidak bergantung Redis, dead-man's switch eksternal. | Alert teruji dengan mematikan Redis & worker | Ya (#3) |
| 6 | **Queue, scheduler, notifikasi**: `onOneServer()`, retry/backoff review, failed-job runbook; (opsional sesuai #4) FCM token lifecycle + date reminders. | Test | Ya (#4) |
| 7 | **Database readiness**: audit index/FK/constraint & N+1 (query log di test), migration safety check, strategi PITR, drill restore di environment terisolasi + prosedur tertulis. | Laporan + drill output | Sebagian (#1) |
| 8 | **Storage failure drills** (isolated): primary down, backup down, corrupt object, DB down, worker crash, restore — memakai `storage:dr-drill` yang ada + skenario baru. | Output drill aktual | Tidak |
| 9 | **Flutter release readiness**: flavor dev/staging/prod via `--dart-define`, applicationId/bundle id final, release signing (keystore di luar Git), cleartext hanya dev, iOS usage strings, crash reporting tanpa PII, error/offline handling review; **account deletion + data export** (backend + app). Release checklist Android & iOS terpisah. | `flutter build appbundle --release` berhasil | Ya (bundle id, #3) |
| 10 | **Performance**: load test (k6) skenario realistis terhadap stack lokal/staging — bukan production. | Angka latency/throughput aktual | Tidak |
| 11 | **Privacy, legal, store**: draft Privacy Policy & ToS jujur (termasuk batas TOFU R7), mapping Data Safety & App Privacy, subscription disclosure; cek kebijakan Apple/Google terbaru. | Dokumen draft (perlu review hukum) | Tidak |
| 12 | **Cost model**: 100 / 1k / 10k / 100k couples dengan beberapa asumsi pemakaian. | Tabel biaya + asumsi | Sebagian (#1, #2) |
| 13 | **Runbooks & README**: arsitektur, setup env, deploy, rollback, backup/restore DB, restore storage, incident response, secret rotation, payment reconciliation, DR plan (RPO/RTO). | Docs | Tidak |
| 14 | **Staging deploy & DR drill** | Deploy staging terverifikasi | Ya (#1) — production **hanya** dengan persetujuan eksplisit |
| 15 | **Final Project Report** | `docs/reports/phase-9-report.md` | — |

Blocker yang **tidak bisa** ditutup hanya dengan kode: integrasi Google Play/App Store nyata (akun & kredensial), dua provider storage nyata, host staging/production, signing key, domain/TLS. Selama itu terbuka, aplikasi **tidak** akan dinyatakan production-ready.
