# Laporan Phase 8 — Subscription, Monetization & Entitlement

Tanggal: 2026-11-07. Detail teknis: [docs/billing/subscriptions.md](../billing/subscriptions.md).

## 1. Hasil audit awal (sebelum coding)

| Area | Temuan | Dampak ke Phase 8 |
|---|---|---|
| Auth & couple | Sanctum + device-bound token; couple maks. 2 anggota; otorisasi lewat keanggotaan. **Belum ada fitur "keluar dari couple".** | Subscription diikat ke `couple_id`; kebijakan keluar didokumentasikan, belum bisa diuji end-to-end. |
| Storage | Foto terenkripsi di primary + backup (Phase 6), `encrypted_size` tersimpan, trash 30 hari. **Belum ada kuota sama sekali.** | Kuota dibangun di atas metadata yang ada; tidak ada perubahan pada pipeline enkripsi/backup. |
| Theme & Photo Booth | Kolom `is_premium` sudah ada tapi tidak ditegakkan. Photo Booth 100% on-device, hasil di-upload sebagai foto terenkripsi biasa. | Premium theme ditegakkan di server; premium Photo Booth hanya bisa di level UI (server tidak bisa melihat layout karena E2E). |
| Notification | **Tidak ada sistem notifikasi/push.** | Sinkronisasi status ke pasangan lewat refresh API, bukan push. |
| Admin | Hanya flag `is_admin`, tanpa role/permission. | Ditambah `admin_permissions` (billing.view / billing.manage / plans.manage), default kosong. |
| Lain-lain | `User::couple()` (hasOne) salah — tabel `couples` tidak punya `user_id`; tidak dipakai di mana pun. README root sudah tertinggal (masih Phase 1–3). Instruksi Laravel Boost di `backend/CLAUDE.md` tidak dijalankan (tidak ada PHP di host; semua lewat Docker). | Tidak memblokir; dicatat untuk dibersihkan. |

## 2. Yang dibangun

**Backend**
- Plan catalog dinamis + versioning (versi published immutable; ganti harga = versi baru).
- Subscription milik couple, satu subscription live per couple (partial unique index).
- Entitlement terpusat (`EntitlementService`), snapshot per subscription.
- Storage quota logis (ciphertext, dihitung sekali, reservasi upload, trash tidak dihitung).
- Lifecycle lengkap: pending, active, grace_period, cancelled, expired, payment_failed, suspended + refund/chargeback/replaced.
- Provider abstraction: **mock store lengkap**; Google Play & App Store terdaftar tapi *fail closed* (belum ada kredensial).
- Webhook: verifikasi signature, idempotency, re-fetch state, abaikan state lama, retry saat outage.
- Scheduler: `billing:sweep` (hourly), `billing:retry-webhooks` (15 menit).
- Filament: Plans (+versions), Entitlements, Subscriptions (+audit trail, transaksi, aksi manual beralasan), Payment webhooks. Permission hanya bisa diberikan lewat CLI.

**Flutter**
- Plan & storage (overview), Compare plans, Purchase flow (konfirmasi → store → verifikasi server), Manage subscription (cancel auto-renew, restore, riwayat), Storage.
- Theme terkunci ditandai; apply ditolak server → pesan jelas. Layout Photo Booth premium disembunyikan bila tidak termasuk paket.
- Release build: tombol beli nonaktif dengan keterangan jujur (belum ada integrasi store).

## 3. Hasil test (aktual)

- Backend: `docker compose run --rm app_test php artisan test` → **314 passed (1263 assertions)**; 33 test baru di `tests/Feature/Billing`.
- Flutter: `flutter analyze` → no issues; `flutter test` → **321 passed**.

## 4. Yang BELUM / batasan

1. **Pembayaran produksi belum berjalan.** Semua alur diuji dengan mock store. Tidak ada uang nyata yang pernah lewat kode ini.
2. Harga, kuota, nama paket = placeholder (seeder dev). Nama "Forever" sengaja diganti "Together+" karena paketnya berulang.
3. Premium Photo Booth hanya ditegakkan di UI (konsekuensi E2E).
4. Tidak ada push notification.
5. Kebijakan keluar couple terdokumentasi, fiturnya belum ada.

## 5. Rekomendasi Phase 9 — Production Readiness, Deployment & Monitoring

Prioritas tinggi
1. **Integrasi store nyata**: akun Play Console & App Store Connect, product id, plugin `in_app_purchase`, implementasi `GooglePlayProvider`/`AppStoreProvider` (sudah ada catatan langkah di file-nya), uji di sandbox/test track, lalu review kebijakan pembayaran terbaru Google/Apple.
2. **Konfigurasi production aman**: pastikan `APP_ENV=production` (mock otomatis mati), `BILLING_MOCK_ENABLED=false`, rahasia di secret manager, `php artisan route:cache`/`config:cache`, HTTPS + HSTS, rate limit webhook di reverse proxy.
3. **Storage**: dua provider/akun object storage yang benar-benar terpisah (dev saat ini SeaweedFS di host yang sama), lifecycle & biaya backup.
4. **Monitoring & alert**: queue backlog, webhook `failed`/`received` > 30 menit, subscription `grace_period`/`payment_failed` meningkat, perbedaan jumlah subscription aktif vs laporan store (rekonsiliasi harian), error rate API, umur backup DB, hasil `db:restore-check`.
5. **Deploy pipeline**: CI menjalankan test backend & Flutter, migrasi terkontrol (migrasi Phase 8 membuat tabel + Free plan), zero-downtime deploy, worker queue & scheduler sebagai service terpisah, health check.

Prioritas menengah
6. Push notification (FCM/APNs) untuk perubahan subscription & masalah pembayaran — tanpa konten pribadi di payload.
7. Fitur "keluar dari couple" mengikuti kebijakan §5 di dokumen billing.
8. Dashboard bisnis non-sensitif (jumlah per plan, churn) tanpa data pribadi.
9. Bersihkan `User::couple()` dan perbarui README root.
10. Uji beban endpoint upload + cek kuota (lock baris couple) dan webhook burst.
