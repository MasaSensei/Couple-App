# Laporan Akhir Phase 9 — Production Readiness, Deployment & Monitoring

Tanggal: 2026-11-07. Branch `phase-8-subscriptions` (perubahan Phase 9 belum di-commit saat laporan ditulis).
Audit awal & rencana: [phase-9-audit.md](phase-9-audit.md). Handbook operasional: [docs/operations/README.md](../operations/README.md).

## Kesimpulan

**Aplikasi BELUM production-ready.** Fondasi teknis untuk production sekarang ada dan
sebagian besar terverifikasi (lihat bukti), tetapi masih ada **blocker kritis** yang
tidak bisa ditutup dengan kode saja (§11): pembayaran store nyata, host staging/production,
monitoring eksternal yang aktif, dua provider storage nyata, signing & identitas app,
halaman legal, dan review kriptografi independen.

## 1. Arsitektur final

Modular monolith (bukan microservices):

```
Flutter ─HTTPS─► Caddy (TLS/HSTS/allowlist admin) ─► Nginx ─► PHP-FPM (API + Filament)
                                                          ├─► PostgreSQL 17 (internal network)
                                                          ├─► Redis 7 (password, AOF, internal)
                                                          ├─► Object storage PRIMARY (provider A)
                                                          └─► Object storage BACKUP  (provider B, object lock)
Queue worker · Scheduler (1) · Migrate (one-off)    ── heartbeat → PostgreSQL + dead-man's switch eksternal
```

Detail tanggung jawab, SPOF, timeout dan budget koneksi: [operations/README.md §1](../operations/README.md#1-architecture).

## 2. Yang benar-benar selesai di Phase 9 (dengan bukti)

| Area | Hasil | Bukti |
|---|---|---|
| Pemulihan dev env | Redis mati 10 jam → queue crash-loop 431×, backup 02:00 terlewat tanpa alert. Dipulihkan; backup #3 + restore-check **passed** (2,8 s) | output perintah |
| Security hardening | rate limit auth/API/upload/public; token kedaluwarsa 60 hari + rotasi + logout-all; MFA admin wajib, admin hanya via CLI, allowlist IP; security headers, CORS, TrustProxies; error 500 tanpa detail + `request_id`; `composer audit` 15 → **0** | `ProductionHardeningTest` (17) |
| Observability | request ID, log JSON + redaksi rahasia, access log per request, `/health/ready` (DB, Redis, 2 store, heartbeat), heartbeat di PostgreSQL + ping eksternal, alert tetap terkirim saat Redis mati, alert billing | `ObservabilityTest` (13) |
| Scheduler/queue | `onOneServer()` di semua jadwal; timeout webhook job; `sanctum:prune-expired` | console.php |
| Docker production | multi-stage, Nginx + PHP-FPM, non-root, service terpisah web/app/queue/scheduler/migrate, healthcheck per peran, resource limit, network internal, Redis berpassword, Caddy TLS, env staging/production terpisah, deploy + rollback + smoke script | image ter-build; stack verifikasi lulus smoke test (kecuali HSTS tanpa TLS) |
| CI/CD | workflow backend (validate, audit, Pint, migrasi fresh/rollback, test, config cache prod, build image, non-root) & Flutter (format, analyze, test, AAB, iOS no-codesign) | file workflow; langkah-langkahnya dijalankan lokal — **workflow belum pernah jalan di GitHub (belum di-push)** |
| Database | 11 FK tanpa index → index `CONCURRENTLY`; tidak ada N+1 di 4 endpoint list; connect timeout 3 s | `QueryBudgetTest` (4), migrasi diterapkan di dev |
| Hapus akun & ekspor data | API + UI; data bersama tetap untuk pasangan (author anonim), anggota terakhir → trash → purge | `AccountDeletionTest` (7), Flutter tests |
| Flutter release | config per environment (`--dart-define`, HTTPS wajib di release), refresh token, offline tidak logout, cleartext hanya debug, backup Android off, izin kamera/foto iOS, signing config, crash hook + scrubbing | `auth_lifecycle_test` (13), AAB release 53,9 MB ter-build |
| Dokumentasi | arsitektur, environment, deploy/rollback, security, monitoring, runbook (alert, insiden, rotasi rahasia, rekonsiliasi pembayaran), database, DR plan, hapus akun, release checklist, privacy/legal, cost model, README | `docs/operations/`, `deploy/README.md` |

Test akhir (run final setelah semua perubahan): backend **354 test, 1436 assertion — OK** (phpunit, 5:14, puncak memori 133 MB); Flutter **334 passed**, analyze `--fatal-infos` bersih, format bersih; Pint 302 file lulus; `composer audit` 0 advisory; `composer validate --strict` valid.

## 3. Bug nyata yang ditemukan saat verifikasi (sudah diperbaiki)

1. Monitoring buta: Redis mati → scheduler & alert ikut mati (insiden 2026-11-07).
2. `docker-php-ext-install opcache` gagal di PHP 8.5.
3. Nginx menyimpan IP lama container app → **502 permanen setelah setiap deploy**.
4. `/health/ready` 500 (bukan 503) saat Redis mati karena rate limiter berbasis Redis.
5. `/health/ready` > 20 s saat store mati (retry SDK) → probe khusus 2 s/3 s tanpa retry.
6. Stack verifikasi tanpa sengaja memakai Redis dev lewat network bersama (hostname sama).
7. Flutter: `created_by` null (akun terhapus) akan membuat app crash.
8. Flutter: app logout saat start offline (semua error menghapus token).
9. Test suite melewati batas memori PHP 128 MB (bukan kebocoran — diukur sama dengan/tanpa logging).
10. Klaim `ITSAppUsesNonExemptEncryption=false` sempat ditambahkan lalu **dicabut** — enkripsi kustom butuh keputusan export-compliance.

## 4. Fitur yang belum selesai

Pembayaran store nyata (Google Play / App Store; masih mock) · push notification & pengingat date · password reset (butuh e-mail) · keluar dari couple · rotasi Couple Key · halaman hapus akun via web (syarat Play) · ekspor foto terdekripsi · crash reporting ke provider · pagination `/dates` & foto per memory.

## 5. Security assessment

Detail: [operations/security.md](../operations/security.md). Ditutup: S1 rate limit, S2 monitoring buta, S3 runtime dev, S4 token tanpa expiry, S5 15 advisory, S6 admin tanpa MFA/eskalasi, S7 hapus akun, S9 cleartext/iOS crash, S10 logout saat offline, S13.
Terbuka: **S8 key package tanpa tanda tangan (TOFU)** — membatasi klaim privasi; S11 password reset; S12 rotasi kunci; S14 pembayaran mock.
Ini review internal, **bukan** audit keamanan independen: pen-test dan review protokol kriptografi eksternal masih wajib.

## 6. Performance assessment

Diukur: tidak ada N+1 di 4 endpoint list, 11 index FK ditambahkan, latency single-request rendah (health 14 ms). **Load test belum dijalankan** — skrip k6 siap, tetapi laptop dev (16 GB) membuat Docker Desktop macet dua kali; angka dari mesin ini tidak representatif. Wajib dijalankan di staging. Detail: [operations/performance.md](../operations/performance.md).

## 7. Storage reliability assessment

Drill kegagalan nyata (run 3): **19 PASS / 2 FAIL**. Backup store mati → foto tidak pernah berstatus *Protected* sampai backup terverifikasi; primary mati → readiness 503 + alert, tidak ada foto "verified" tanpa salinan; objek korup terdeteksi dan diperbaiki dari backup (SHA-256 identik); worker mati → job menunggu, tidak hilang. Recovery drill Phase 6 (primary hilang + restore DB → semua foto terdekripsi identik) tetap berlaku.
Batasan: dua store dev berada di satu host — **belum ada pemisahan failure domain nyata**.

## 8. Backup & recovery assessment

Backup DB terenkripsi harian + restore-check: **passed** hari ini (backup #3, 2,8 s; dan drill F). RPO saat ini 24 jam, RTO target 4 jam (belum diukur dengan volume nyata). Drill E (database mati) **gagal**: readiness/API tidak menjawab < 20 s karena lookup DNS container yang berhenti — temuan terbuka. DR plan 10 skenario: [operations/disaster-recovery.md](../operations/disaster-recovery.md).

## 9. Deployment status

**Belum ada deployment ke mana pun.** Image production ter-build dan lulus verifikasi lokal; skrip deploy/rollback/smoke tersedia; workflow CI ditulis tetapi belum jalan di GitHub. Staging dan production belum ada (butuh host, domain, registry).

## 10. Monitoring status

**Terkonfigurasi, belum aktif.** Health/readiness, heartbeat, alert, log terstruktur & redaksi sudah ada dan teruji. Uptime monitor eksternal, layanan heartbeat, Slack, platform log dan crash reporting belum disambungkan (butuh pilihan provider + host).

## 11. Operational cost estimate

±$35/bulan (100 couples), ±$80–110 (1.000), ±$520 (10.000), ±$3.300–3.500 (100.000), dari asumsi 0,33 GB/couple/tahun. Detail & asumsi: [operations/cost-model.md](../operations/cost-model.md). Harga harus dicek ulang ke provider terpilih.

## 12. Known limitations & remaining risks

**Blocker kritis (production tidak boleh dinyatakan siap):**
1. Pembayaran store nyata belum diimplementasikan.
2. Tidak ada host staging/production, domain, TLS, registry; belum ada deploy yang terverifikasi di staging.
3. Monitoring eksternal belum aktif.
4. Dua provider object storage nyata belum dipilih/dipasang.
5. Identitas app (application id/bundle id), signing Android/iOS, build iOS belum dilakukan.
6. Privacy policy, ToS, halaman hapus akun web belum ada; keputusan export compliance iOS.
7. Review kriptografi independen + pen-test belum dilakukan (TOFU S8).
8. Drill E (DB mati → respons lambat) belum terselesaikan.

Risiko lain: RPO DB 24 jam sampai PITR aktif; load test belum ada; password reset belum ada (user yang lupa password terkunci); rotasi kunci belum ada.

## 13. Rekomendasi langkah berikutnya

1. Putuskan hosting, 2 provider storage, monitoring/crash provider, application id → siapkan staging, jalankan CI di GitHub, deploy staging.
2. Di staging: load test k6, drill kegagalan + recovery, ukur RTO restore dengan volume realistis, perbaiki drill E.
3. Implementasi billing store (sandbox) + rekonsiliasi.
4. Password reset (e-mail), halaman legal & hapus akun web, privacy manifest iOS.
5. Review kriptografi eksternal (prioritas: tanda tangan key package) dan pen-test.
6. Setelah semua blocker tertutup: persetujuan owner → production.
