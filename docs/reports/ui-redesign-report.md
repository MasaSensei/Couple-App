# UI/UX Redesign — Laporan Akhir (Step 1–7)

Tanggal: 2026-11-08 · Branch: `phase-9-production-readiness` · Status: **selesai, belum di-commit**.

Dokumen terkait: [audit](../design/ui-ux-audit.md) · [design direction](../design/design-direction.md) · [design system](../design/design-system.md).

## 1. Ringkasan

| Area | Sebelum | Sesudah |
|---|---|---|
| Identitas | Material default, primary `#E8899B` (teks putih 2.48:1) | "Paper, ink & rosewood": Rosewood `#B4475F` (5.24:1), Playfair + Nunito + Dancing Script, wordmark *our little space ♥* |
| Navigasi | Home = 7 tombol outline; Logout 1-tap di AppBar | Bottom nav 4 tab (Home · Dates · Memories · Me), Logout di Me dengan konfirmasi |
| Home | Ikon hati + jumlah member + daftar tombol | Header pasangan + anniversary, next date (tiket), polaroid journal, quick actions, recent activity |
| Memory timeline | Kartu teks tanpa foto | Foto cover terdekripsi di perangkat, dikelompokkan per bulan, 3 gaya (soft/polaroid/minimal) |
| Date planner | Kartu teks, status `PLANNED` mentah | Week strip, Upcoming/Past, tiket dengan DateBadge, status chip berwarna+ikon+teks |
| Photo Booth | Satu halaman panjang | Studio: stage preview, 3 langkah, action bar tetap |
| Themes | Grid preview sederhana | Preview nyata dengan komponen tema, tagline, status Applied/Paid plan |
| Settings | Tersebar | Me: Our couple, Appearance, Plan & storage, Privacy & security, Support |
| Tema | Token hanya warna/radius dasar | + surfaceMuted, paper, warning, info, 5 gaya teks baru, radius chip/sheet/foto, elevation, **ornamen per tema** (9 berbeda), `context.motion` |
| Admin | Amber, tanpa grup, `FilamentInfoWidget` | Brand Rosewood/Stone, font self-hosted, 5 grup sidebar, dashboard data nyata, status warna terpusat, tabel & detail bersection |

## 2. Perubahan API (aditif, disetujui di Step 1)

| Endpoint | Perubahan | Kompatibilitas |
|---|---|---|
| `GET /memories`, `GET /memories/timeline` | + `photos_count`, + `cover_photo` (metadata ciphertext `MemoryPhotoResource`, sama seperti `GET /memories/{id}/photos`; `null` bila tanpa foto) | Aditif; klien lama mengabaikan. Query tetap konstan (2 query foto per halaman, diuji) |
| `GET /couple` | + `relationship_started_at` (`Y-m-d` / `null`) | Aditif |
| `PATCH /couple` *(baru)* | `{ "relationship_started_at": "YYYY-MM-DD" \| null }`; tidak di masa depan, ≥ 1900; anggota mana pun; field lain diabaikan | Baru |
| Migrasi | `couples.relationship_started_at date null` | Aman (nullable) |
| Export data | + `relationship_started_at` di objek couple | Aditif |

Tidak ada perubahan pada auth, otorisasi, aturan keanggotaan, entitlement, enkripsi, key management, proteksi storage, atau workflow backup. Foto tetap didekripsi di perangkat; tidak ada URL publik; admin tetap tidak bisa melihat foto.

## 3. Catatan keamanan & privasi yang ditambahkan

- **Cache foto terdekripsi** (`MemoryPhotoNotifier`): LRU di memori saja (maks 32 foto / 48 MB), tidak pernah ke disk, kunci = id + checksum, **dibersihkan saat logout** dan saat reset kunci. Sebelumnya couple key juga tidak dibersihkan saat logout; sekarang ikut dibersihkan.
- **Admin:** invite code di-mask (`••••••34`) di daftar & detail couple; halaman couple hanya menampilkan jumlah, bukan isi memory; statistik billing di dashboard mengikuti izin `billing.view`; font admin tidak lagi dari `fonts.bunny.net`.
- Status "Protected" tetap hanya bila backup `verified` (aturan `protectionStatus()` tidak diubah).

## 4. Hasil test (dijalankan 2026-11-08)

| Suite | Hasil |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **406 lulus**, 2 di-skip (snapshot visual, opt-in) — baseline sebelumnya 334 |
| Cross-theme (`screens_across_themes_test.dart`) | Home/Dates/Memories/Me × 9 tema × light/dark × (390×844 @1.0, 360×740 @1.3) tanpa overflow/exception |
| Snapshot visual | 64 PNG layar + 16 PNG komponen (`build/visual/…`), contact sheet di `docs/design/img/` |
| Backend `php artisan test` (Docker `app_test`) | **373 lulus** (1532 assertion) |
| `vendor/bin/pint --test` | PASS (312 file) |
| Admin visual (browser lokal) | Halaman login & setup 2FA dengan brand baru terverifikasi; dashboard di balik 2FA diverifikasi lewat feature test (tidak didaftarkan 2FA untuk akun uji) |
| Android | `flutter build apk --debug` berhasil (169 s). Tidak ada emulator/perangkat terhubung, jadi belum dijalankan di perangkat |
| iOS | Tidak tersedia di environment Windows ini |

Masalah yang ditemukan oleh test baru lalu diperbaiki: overflow `AppStateView` di layar pendek, overflow header bulan timeline pada teks 1.3×, overflow preview tema, warna selotip Classic Rose dark, warna bintang Starry Night, teks fitur "not included" berkontras rendah (sebelumnya memakai warna border).

## 5. Keterbatasan / belum dikerjakan

- **Notification Center** tidak ada di produk (sesuai keputusan, diganti "Recently" di Home; komentar tidak termasuk karena butuh 1 request per memory).
- **Theme detail, devices, invite/accept, recovery key, restore access, storage & subscription management**: memakai komponen/token baru lewat `ThemeData` dan pembersihan copy, tetapi tidak dirombak tata letaknya.
- Edit tanggal jadian ada di **Me → Anniversary**; belum ada di onboarding.
- `backend/CLAUDE.md` meminta instalasi PHP/Composer/Laravel Boost di host; tidak dilakukan (project memakai PHP via Docker, dan instalasi paket baru butuh persetujuan).

## 6. Android

`flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk` (sukses). Tidak ada emulator atau perangkat yang terhubung (`flutter devices` hanya Chrome/Edge), jadi uji di perangkat nyata masih perlu dilakukan.
