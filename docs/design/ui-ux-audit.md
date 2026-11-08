# UI/UX Audit — Step 1 (Redesign "Cute Romantic Editorial")

Tanggal: 2026-11-08 · Branch: `phase-9-production-readiness` · Baseline: `flutter analyze` 0 issue, `flutter test` 334 lulus.

Audit ini dibuat dari kode aktual (bukan asumsi). Belum ada perubahan kode.

---

## 1. Ringkasan temuan utama

| # | Temuan | Dampak | Kategori |
|---|---|---|---|
| A1 | **Tidak ada app shell / bottom navigation.** Home adalah satu kolom berisi 7 `OutlinedButton` (Dates, Memories, Photo Booth, Devices, Plan & storage, Invite) + 3 ikon di AppBar (Themes, Account, **Logout**). | Home terasa seperti menu CRUD; fitur inti jauh dari jempol; Logout satu-tap tanpa konfirmasi di AppBar. | Navigation |
| A2 | **Routing campuran:** go_router hanya punya 7 route (`/splash`, `/login`, `/register`, `/home`, `/memories`, `/memories/create`, `/devices`); ±45 navigasi lain memakai `Navigator.push(MaterialPageRoute)`. | Tidak bisa deep-link, transisi tidak konsisten, back-stack sulit dikontrol saat bottom nav ditambahkan. | Architecture |
| A3 | **Memory timeline tidak punya foto.** `MemoryModel` tidak memiliki cover photo / jumlah foto; `MemoryCard` hanya teks (tanggal, judul, lokasi, deskripsi). | Syarat "photo-first / polaroid" tidak bisa dipenuhi tanpa data cover. Lihat §6 (butuh keputusan). | Data gap |
| A4 | **Couple tidak punya informasi hubungan** (anniversary/tanggal jadian). `CoupleModel` = `id`, `inviteCode`, `members`, `createdAt`. | "Together for N days" tidak bisa ditampilkan jujur (`createdAt` = tanggal space dibuat, bukan tanggal jadian). | Data gap |
| A5 | **Notification Center tidak ada** — tidak ada layar, model, atau endpoint notifikasi in-app (backend hanya punya webhook billing). | Tidak bisa "di-redesign"; hanya bisa dibangun sebagai fitur baru. | Scope |
| A6 | **Tidak ada layar Profile & Settings terpadu.** Pengaturan tersebar: Themes (AppBar), Account & data (AppBar), Devices (tombol home), Plan & storage (tombol home), Recovery key (banner). | Sulit ditemukan; tidak ada grup Account/Couple/Appearance/Privacy/Support. | IA |
| A7 | **Theme system Phase 7 sudah kuat** (ThemeDefinition → AppThemeTokens `ThemeExtension` yang di-lerp, 8 tema, preset aksen/background/font, dekorasi + animasi yang menghormati reduce-motion). Tapi token **belum cukup kaya** untuk redesign: tidak ada surface varian, shadow scale, warna warning/info, "on" color untuk success/error, gaya chip/badge, gaya nav bar, ornamen per komponen. | Redesign bisa dibangun di atasnya **tanpa mengubah sinkronisasi**; cukup memperluas token. | Theme |
| A8 | **State UI tidak konsisten:** loading/empty/error diimplementasi ulang per layar (≥8 variasi). Date list error tidak punya tombol retry; memory list memakai `Theme.textTheme`, home memakai `tokens`. Tidak ada state offline umum. | Pengalaman tidak konsisten, kode duplikat. | States |
| A9 | **Bahasa campur:** Memory detail berbahasa Indonesia ("Tambah Foto", "Hapus foto?", "Pulihkan"), layar lain Inggris. | Inkonsistensi copy. Perlu keputusan bahasa (lihat §6). | Copy |
| A10 | **Filament hampir default:** warna `Amber`, tanpa logo/font, dashboard berisi `AccountWidget` + `FilamentInfoWidget` (widget promosi Filament), Users & Couples tanpa grup dan memakai ikon generik yang sama (`RectangleStack`), 0 `Section`/`Tabs` di semua infolist/form. | Admin terlihat seperti scaffold awal. | Admin |

---

## 2. Inventory layar Flutter

Kolom: **Tokens** = jumlah pemakaian `context.tokens` (theme-aware); **BG** = memakai `ThemedBackground`; **Push** = navigasi `Navigator.push`.

| Layar | File | Baris | Tokens | BG | Push | Catatan audit |
|---|---|---|---|---|---|---|
| Splash | `splash/presentation/splash_screen.dart` | 122 | 7 | – | – | OK, polos. |
| Login | `auth/.../login_screen.dart` | 136 | 3 | – | – | Pakai `AppButton`/`AppTextField`; tanpa identitas brand/ilustrasi. |
| Register | `auth/.../register_screen.dart` | 178 | 3 | – | – | Sama dengan login. |
| Home / Couple Space | `home/presentation/home_screen.dart` | 395 | 10 | ✓ | 17 | Ikon hati 64px + "Hello ♡", kartu "N member(s)" + email partner, lalu 7 tombol outline. Tidak ada highlight memory, upcoming date, atau aktivitas. (A1) |
| Invite partner | `home/presentation/invite_partner_screen.dart` | 140 | 5 | – | – | |
| Accept invitation | `home/presentation/accept_invitation_screen.dart` | 108 | 3 | – | – | |
| Date list | `home/presentation/date_list_screen.dart` | 175 | 8 | – | 3 | List card teks; status ditampilkan `status.toUpperCase()` sebagai teks polos; format tanggal `dd/mm/yyyy • hh:mm` ditulis manual; radius InkWell hardcoded `20` (tidak ikut tema); error tanpa retry; tidak ada kalender, pengelompokan upcoming/past. |
| Date detail | `home/presentation/date_detail_screen.dart` | 469 | 8 | – | 6 | Status juga `toUpperCase()`; komentar di `date_comments_section.dart`. |
| Date form | `home/presentation/date_form_screen.dart` | 266 | 4 | – | – | `showDatePicker` default. |
| Memory timeline | `memories/presentation/screens/memory_list_screen.dart` | 236 | 5 | ✓ | 2 | Pagination infinite-scroll sudah benar. Tanpa foto, tanpa pengelompokan bulan/tahun. Empty state tinggi hardcoded `400`. (A3) |
| Memory card | `memories/presentation/widgets/memory_card.dart` | 140 | 11 | – | – | Varian `soft/polaroid/minimal` sudah ada tapi "polaroid" hanya radius 4 + elevation 3, tanpa foto. Array nama bulan duplikat. |
| Memory detail | `memories/presentation/screens/memory_detail_screen.dart` | 516 | 21 | ✓ | 2 | Grid foto terenkripsi, trash/restore. Copy Bahasa Indonesia. |
| Memory form | `memories/presentation/screens/memory_form_screen.dart` | 305 | 7 | – | – | |
| Photo viewer | `memories/presentation/screens/memory_photo_viewer_screen.dart` | 220 | 0 | – | – | Hitam penuh (`Colors.black`) — wajar untuk viewer. |
| Memory comments | `memories/presentation/widgets/memory_comment_section.dart` | 432 | **0** | – | – | Tidak memakai token sama sekali; 5 `EdgeInsets` literal. |
| Memory protection | `memories/presentation/widgets/memory_protection_card.dart` | 180 | 14 | – | – | Bottom sheet status proteksi. |
| Photo Booth | `photo_booth/presentation/photo_booth_screen.dart` | 401 | 6 | – | – | Satu halaman scroll panjang: Layout list → toggle "Show date" → Photos → preview → Save/Share. Belum terasa "studio kreatif"; tidak ada langkah/tahapan. |
| Photo Booth sources | `photo_booth/presentation/photo_booth_sources.dart` | 308 | 7 | – | – | Picker dari galeri / memory (bottom sheet). |
| Theme gallery | `appearance/presentation/theme_gallery_screen.dart` | 343 | 8 | – | 2 | Sudah ada preview mini (`theme_preview.dart` merender `ThemedBackground` dengan token tema lain) + mode System/Light/Dark + Reduce motion + offline banner. Fondasi bagus. |
| Theme detail | `appearance/presentation/theme_detail_screen.dart` | 338 | 6 | – | – | Chip preset aksen/background/font, toggle dekorasi/animasi, Couple Space style, Memory style. |
| Subscription overview | `subscription/presentation/subscription_overview_screen.dart` | 219 | **0** | – | 6 | Hanya ikut `ThemeData` (warna), tidak ikut tipografi display/dekorasi tema. |
| Plan comparison | `subscription/presentation/plan_comparison_screen.dart` | 192 | **0** | – | – | List kartu per plan; belum format tabel perbandingan. Sekilas tidak terlihat dark pattern (dicek ulang di Step 4). |
| Subscription management | `subscription/.../subscription_management_screen.dart` | 192 | **0** | – | – | |
| Storage | `subscription/presentation/storage_screen.dart` | 126 | **0** | – | 2 | `LinearProgressIndicator` di `subscription_widgets.dart`. |
| Account & data | `account/presentation/account_screen.dart` | 195 | **0** | – | – | Export data + delete account (konfirmasi + checkbox — bagus). |
| Devices | `device/data/presentation/screens/device_management_screen.dart` | 221 | **0** | – | – | Path folder salah tempat (`device/data/presentation`). |
| Recovery key setup | `privacy/presentation/recovery_key_setup_screen.dart` | 291 | 10 | – | – | |
| Restore access | `privacy/presentation/restore_access_screen.dart` | 174 | 6 | – | – | |
| Encryption banner | `privacy/presentation/encryption_status_banner.dart` | 53 | 0 | – | 1 | `ListTile` di dalam `Card`. |
| Partner theme banner | `appearance/presentation/partner_theme_banner.dart` | 63 | 2 | – | 2 | |
| **Notification Center** | — | — | — | — | — | **Tidak ada.** (A5) |
| **Profile & Settings** | — | — | — | — | — | **Tidak ada layar terpadu.** (A6) |

### Komponen bersama yang ada (`lib/core/widgets`)
`AppButton` (32 baris), `AppTextField` (47), `AppLoading` (20). Hanya dipakai di auth, form, privacy. Tidak ada: empty state, error state, section header, status badge, avatar pasangan, list group/settings tile, photo frame, date badge.

---

## 3. Theme system (Phase 7) — kondisi aktual

**Arsitektur** (tetap dipertahankan):
```
ThemeDefinition (data, 8 tema)  ─┐
ThemeCustomization (preset key) ─┼─► AppTheme.resolveTokens() ─► AppThemeTokens (ThemeExtension, lerp)
Brightness / ThemeMode          ─┘                              └► ThemeData (AppBar, Card, Input, Button, FAB, Chip)
Sync: appearance_controller ↔ PUT /couple/theme; cache SharedPreferences; refresh saat app resume.
```

**Yang sudah baik**
- Pergantian tema dianimasikan oleh `MaterialApp`/`AnimatedTheme` tanpa rebuild route (syarat "tanpa reload" sudah terpenuhi).
- Dekorasi `ThemedBackground` = `IgnorePointer` + `ExcludeSemantics` + `RepaintBoundary`, opacity rendah, animasi mati bila tema/couple/user/OS reduce-motion menolak.
- Font dibundel (tidak ada request ke Google Fonts).
- Kontras palet dasar semua tema lulus WCAG AA (dihitung dari hex):

| Tema | onPrimary/primary | textPrimary/bg | textSecondary/bg | textSecondary/surface |
|---|---|---|---|---|
| Sakura light / dark | 5.49 / 7.30 | 13.05 / 15.24 | 5.94 / 8.97 | 6.35 / 8.08 |
| Winter Love | 6.13 / 8.60 | 13.49 / 15.65 | 5.91 / 9.15 | 6.31 / 8.07 |
| Midnight (dark only) | 8.80 | 16.72 | 8.82 | 7.90 |
| Vintage Film | 6.94 / 7.80 | 11.65 / 14.51 | 5.95 / 8.57 | 6.48 / 7.49 |
| Imperial Winter | 7.45 / 7.66 | 14.55 / 15.88 | 6.30 / 8.72 | 6.77 / 7.82 |
| Cottage | 6.01 / 8.20 | 11.38 / 15.30 | 5.32 / 9.38 | 5.91 / 8.25 |
| Café | 7.17 / 8.13 | 13.24 / 15.30 | 6.08 / 8.85 | 6.73 / 7.86 |
| Starry Night (dark only) | 11.27 | 15.71 | 9.42 | 8.33 |

**Gap untuk redesign**
1. `success` default `#7BBF9A` ≈ **2.1:1** dan `error` `#D96B76` ≈ **3.5:1** di atas putih — gagal AA bila dipakai sebagai teks/ikon kecil. Tidak ada `warning`/`info`, tidak ada `onSuccess/onError`.
2. Tidak ada token: `surfaceMuted`/`surfaceRaised`, shadow/elevation scale, ukuran tipografi `label`/`caption`/`overline`, gaya nav bar, gaya chip/badge, warna "kertas" untuk frame polaroid, ornamen kecil per komponen (washi tape, stamp, dsb).
3. `AppSpacing`/`AppRadius` global statis — baik (spacing memang sebaiknya tidak per tema), tapi radius komponen selain card/button (chip, sheet, photo frame) belum ada.
4. `ThemeComponentStyle.navigation` hanya memengaruhi AppBar; belum ada bottom nav.
5. 9 file presentation (subscription ×4, account, devices, comments, encryption banner, viewer) memakai **0** token → tidak mengikuti tipografi tema.
6. `AppColors`/`AppTextStyles` lama hanya dipakai sebagai fallback di `core/theme` (tidak bocor ke layar) — aman.

---

## 4. Inventory Filament Admin

**Panel** (`app/Providers/Filament/AdminPanelProvider.php`): `primary => Color::Amber`, tanpa `brandName`/`brandLogo`/`font`/`favicon`, MFA aktif (bagus), `RestrictAdminAccess` middleware.

| Resource / Widget | Grup nav | Ikon | Filter | Badge | Search | Catatan |
|---|---|---|---|---|---|---|
| Users | *(none)* | `RectangleStack` (generik) | 0 | 0 | 2 | `recordTitleAttribute = 'Users'` → **bug**: nama atribut literal "Users", judul record kosong. Ada `CreateUser`/`EditUser` page di folder tapi tidak terdaftar di `getPages()`. |
| Couples | *(none)* | `RectangleStack` (sama) | 0 | 0 | 1 | `recordTitleAttribute = 'id'`; kolom `invite_code` ditampilkan & searchable — perlu ditinjau (kode undangan adalah secret pendek). Infolist tanpa Section. |
| Couple subscriptions | Billing | CreditCard | 2 | 2 | 1 | + Events, Transactions relation managers. |
| Subscription plans | Billing | Tag | 0 | 1 | 0 | + Versions relation manager. |
| Entitlements | Billing | Key | 0 | 0 | 0 | |
| Payment webhooks | Billing | Bolt | 1 | 1 | 0 | |
| Themes | Appearance | Swatch | 0 | 1 | 1 | |
| Photo Booth templates | Appearance | Photo | 0 | 1 | 1 | |
| Photo storage | Storage | ServerStack | 1 | 1 | 0 | **18 kolom** (8 toggleable) — terlalu padat; tidak menampilkan foto (benar, hanya metadata ciphertext). |
| Storage audit log | Storage | ClipboardDocumentList | 2 | 1 | 0 | |
| Database backups | Storage | CircleStack | 0 | 2 | 0 | |
| Widget `StorageHealthOverview` | Dashboard | – | – | – | – | 7 stat nyata (alerts, protected, degraded, repairs 7d, DB backup age, storage used, queue), polling 60s. Satu-satunya widget domain. |
| `AccountWidget`, `FilamentInfoWidget` | Dashboard | – | – | – | – | Default Filament; `FilamentInfoWidget` sebaiknya dihapus. |

**Gap admin**
- 0 `Section::make`/`Tabs::make` di seluruh schema → halaman view/edit datar tanpa hierarki.
- 0 custom empty state.
- Grup navigasi tidak ada untuk Users/Couples; tidak ada urutan (`navigationSort`).
- Dashboard tidak menampilkan total users, couples, active subscriptions, failed jobs (data tersedia di DB: `users`, `couples`, `couple_subscriptions`, `failed_jobs`; `StorageHealthService` sudah menyediakan metrik storage/backup).
- Status color mapping didefinisikan per tabel (mis. `PROTECTION_COLORS` lokal) → belum ada sumber tunggal.
- Perlu diverifikasi di Step 5: definisi `protectionStatus() === 'protected'` harus mensyaratkan backup terverifikasi (spec §6F).

---

## 5. Masalah lintas-layar (checklist)

| Area | Temuan |
|---|---|
| Default components | `OutlinedButton` stack di home, `ListTile` polos di account/devices/banner, `showDatePicker` & `AlertDialog` default, `CircularProgressIndicator` mentah di ±20 tempat. |
| Inkonsistensi gaya | Dua jalur teks (`context.tokens.*` vs `Theme.of(context).textTheme.*`); radius hardcoded `20` di date list; format tanggal ditulis manual di ≥3 file tanpa `intl`. |
| Hierarki informasi | Home: data paling penting (pasangan, momen, rencana) kalah oleh daftar tombol. Date card: status tidak menonjol. |
| Duplikasi | Empty/error/loading state, format tanggal, pembungkus `Card + InkWell + Padding`. |
| Missing states | Date list error tanpa retry; tidak ada banner offline global (hanya Theme gallery yang punya); skeleton loading tidak ada. |
| Navigasi | Tanpa bottom nav; Logout satu-tap; Devices/Plan sejajar dengan fitur inti; tidak ada Settings. |
| Theme integration | 9 file tanpa token; `ThemedBackground` hanya di 4 tempat; bottom nav belum ada sehingga `NavigationStyle` belum berarti apa-apa di sana. |
| Responsif | Semua layar satu kolom; tidak ada batas lebar konten untuk tablet/landscape; empty state tinggi tetap 400px. |
| Accessibility | `Semantics` eksplisit hanya di 6 file; ikon hati besar dekoratif belum `ExcludeSemantics`; success/error warna kontras rendah. Touch target default Material (≥48dp) — OK. |

---

## 6. Keputusan yang dibutuhkan sebelum Step 2/3

1. **Cover foto di Memory Timeline (A3).** Opsi:
   - (a) *Tanpa ubah API:* timeline tetap teks + "photo strip" diambil lazily per kartu yang terlihat via endpoint foto yang ada (N request + dekripsi di klien per kartu; perlu cache & batas). Berisiko boros jaringan/baterai.
   - (b) *Tambah field read-only aditif* di respons list memory (mis. `cover_photo_id`, `photos_count`) — tidak memecah kontrak lama, foto tetap terenkripsi & didekripsi di klien. **Rekomendasi saya.** Butuh persetujuan karena menyentuh API.
2. **Anniversary/relationship date (A4).** Tanpa field baru, home hanya menampilkan "Space sejak {createdAt}" dengan label jujur. Menambah field = perubahan API + migrasi. Mau ditambahkan atau tidak?
3. **Notification Center (A5).** Tidak ada fitur. Pilihan: keluarkan dari scope redesign, atau tampilkan sebagai "Recent activity" berbasis data yang sudah ada (date/memory/comment terbaru) tanpa push.
4. **Bahasa UI (A9).** Seragamkan ke Inggris (mayoritas saat ini) atau Indonesia?
5. **Routing (A2).** Untuk bottom nav, saya usulkan `StatefulShellRoute` go_router (4 tab) — refactor navigasi menengah, tanpa mengubah business logic. Layar sekunder tetap boleh `Navigator.push` untuk sementara.

---

### Keputusan (disetujui 2026-11-08)

1. Memory list mendapat field aditif read-only `cover_photo_id` + `photos_count`; foto tetap terenkripsi, dekripsi di klien.
2. Tanggal jadian: field baru opsional (`relationship_started_at`) di couple + migrasi; tanpa nilai → Home menampilkan "Our space since {createdAt}".
3. Notification Center diganti "Recent activity" di Home dari data date/memory/comment yang ada (tanpa push).
4. Bahasa UI diseragamkan ke Inggris.
5. Bottom navigation 4 tab via `StatefulShellRoute` go_router.

## 7. Rencana Step berikutnya

- **Step 2 — Design Direction:** proposal palet brand ("Rosewood / Paper / Ink"), tipografi, spacing/radius/shadow, ikonografi, gaya komponen, motion, + mockup Home, Memory Timeline, Date Planner, Theme Gallery, dan Admin Dashboard (dipublikasikan sebagai halaman visual). Tidak ada perubahan kode sebelum disetujui.
