# Design Direction — "Cute Romantic Editorial"

Step 2 redesign · 2026-11-08 · Status: **proposal, menunggu persetujuan**. Mockup visual: lihat artifact "Little Space Design Direction".

Konsep: **buku kenangan digital yang hidup.** Kertas hangat, tinta lembut, foto sebagai pusat, dan sedikit "tempelan" scrapbook (selotip washi, cap tanggal, tulisan tangan) yang hanya muncul di tempat yang memang berupa *kenangan* (foto, tanggal, catatan). Bagian lain (settings, form, billing) tetap bersih seperti jurnal yang tertata.

Nama brand kerja: **Our Little Space** (sudah dipakai sebagai judul Home). Wordmark: "our little space" huruf kecil, Playfair Display italic + hati kecil sebagai titik.

---

## 1. Prinsip

1. **Konten dulu, ornamen kedua.** Ornamen hanya di tepi foto/kartu kenangan, tidak pernah di atas teks atau tombol. Maksimal satu ornamen per kartu.
2. **Satu suara tulisan tangan.** Font handwriting hanya untuk caption pendek (≤ 40 karakter): caption polaroid, "from {partner}", sapaan. Tidak pernah untuk body, tombol, atau angka.
3. **Hangat, bukan pink.** Netral bernuansa hangat (kertas, tinta) membawa 80% layar; warna brand hanya untuk aksi dan sorotan.
4. **Tema mengubah karakter, bukan tata letak.** Struktur layar sama di semua tema; yang berubah adalah palet, tipografi, bentuk, ornamen, dan motion.
5. **Aksesibilitas tidak bisa ditawar.** Semua pasangan teks/latar ≥ 4.5:1, touch target ≥ 48dp, semua ornamen `ExcludeSemantics`, semua animasi mati saat reduce motion.

---

## 2. Brand palette (tema default "Classic Rose", key tetap `classic_rose`)

Key tema tidak berubah agar sinkronisasi couple tetap valid; isinya diperbarui ke palet brand.

| Token | Light | Dark | Peran | Kontras |
|---|---|---|---|---|
| `primary` — Rosewood | `#B4475F` | `#F2A0B2` | Aksi utama, tab aktif, link | putih di atasnya 5.24 · di atas paper 4.93 |
| `onPrimary` | `#FFFFFF` | `#3A121C` | Teks di atas primary | — |
| `secondary` — Blush | `#F7DCE1` | `#4A2A33` | Fill lembut, chip terpilih, highlight | rosewood di atas blush 4.06 (hanya ikon/teks ≥ 18px) |
| `accent` — Marigold | `#C9822F` | `#E7B36F` | Cap tanggal, bintang, ornamen | 3.13 → **dekoratif saja**, tidak untuk teks |
| `background` — Paper | `#FCF7F4` | `#1C1417` | Latar layar | — |
| `surface` | `#FFFFFF` | `#281D21` | Kartu | — |
| `surfaceMuted` *(baru)* | `#F6EDE9` | `#33262B` | Grup settings, input, skeleton | inkSoft di atasnya 5.01 |
| `paper` *(baru)* | `#FFFDF9` | `#F3ECE6` | Bingkai polaroid (tetap terang di dark mode, seperti cetakan foto) | — |
| `textPrimary` — Ink | `#34262B` | `#F6EAEE` | Judul & body | 13.54 / 15.43 |
| `textSecondary` — Ink soft | `#75606A` | `#C9AEB7` | Meta, caption | 5.43 / 7.94 |
| `border` | `#EBDCD6` | `#44323A` | Garis kartu & divider | — |
| `success` — Sage | `#3F7D5C` | `#8CC7A5` | Selesai, terlindungi | 4.88 |
| `warning` *(baru)* — Amber | `#9A5B12` | `#E8B66B` | Perlu perhatian | 5.41 |
| `error` — Berry | `#B3394A` | `#F2A3AC` | Gagal, destruktif | 5.83 |
| `info` *(baru)* — Dusk | `#386A92` | `#9CC3E4` | Informasi netral | 5.76 |

Catatan: primary lama `#E8899B` dengan teks putih hanya **2.48:1** (gagal AA). Ini salah satu alasan palet default diperbarui.

Semua 8 tema lain mempertahankan palet Phase 7-nya, lalu ditambah token baru (`surfaceMuted`, `paper`, `warning`, `info`, `onSuccess`, dll.) yang diturunkan otomatis bila tema tidak mendefinisikannya.

---

## 3. Typography

Semua font sudah dibundel (tidak ada dependency atau request baru).

| Peran | Default (Classic Rose) | Ukuran / berat / line-height | Dipakai untuk |
|---|---|---|---|
| `display` | Playfair Display | 32 / 600 / 1.15 | Nama pasangan, judul bulan di timeline |
| `title` | Playfair Display | 22 / 600 / 1.25 | Judul layar & kartu utama |
| `heading` *(baru)* | Nunito | 17 / 700 / 1.3 | Judul section, judul kartu biasa |
| `body` | Nunito | 15 / 400 / 1.5 | Teks utama |
| `label` *(baru)* | Nunito | 13 / 600 / 1.3, +0.2 letter-spacing | Tombol kecil, chip, tab |
| `caption` *(baru)* | Nunito | 12.5 / 500 / 1.4 | Meta, timestamp |
| `overline` *(baru)* | Nunito | 11 / 700 / 1.2, +1.2, UPPERCASE | Eyebrow section ("NEXT DATE") |
| `handwriting` *(baru)* | Dancing Script | 20 / 500 | Caption polaroid, sapaan |
| `numeric` | Nunito + `tabularFigures` | — | Countdown, angka storage |

Tiap tema menimpa family `display`/`body`/`handwriting` (mis. Vintage Film: Courier Prime / Lora / Courier Prime; Imperial Winter: Cormorant / Lora / Dancing Script; Winter Love: Quicksand semua + Dancing Script). Semua ukuran memakai `TextScaler` sistem (tidak ada `textScaleFactor` tetap); layout diuji sampai 1.3×.

---

## 4. Spacing, radius, elevation

**Spacing** (grid 4pt, global, tidak per tema): `xxs 2 · xs 4 · sm 8 · smd 12 · md 16 · lg 24 · xl 32 · xxl 48`. Gutter layar 20 (phone), lebar konten maks 640 (tablet/landscape, center).

**Radius** (global, kartu & tombol tetap dari tema): `xs 6 · sm 10 · md 14 · lg 20 · xl 28 · pill`. Baru per tema: `chipRadius`, `sheetRadius`, `photoRadius` (foto di dalam bingkai).

**Elevation** — bayangan lembut berwarna tinta (bukan hitam), 3 tingkat:

| Level | Light | Dipakai |
|---|---|---|
| `e1` | 0 1 2 tinta 6% + 0 2 8 tinta 4% | Kartu biasa (bila tema tanpa border) |
| `e2` | 0 4 14 tinta 8% | Polaroid, kartu "next date" |
| `e3` | 0 12 32 tinta 12% | Bottom sheet, nav bar mengambang |

Dark mode: bayangan diganti outline 1px `border` + sedikit lift warna surface (bayangan tidak terlihat di latar gelap).

---

## 5. Iconography & ilustrasi

- **Flutter:** Material Symbols *Rounded* (`Icons.*_rounded`, sudah tersedia — tanpa paket baru). 24dp, stroke outlined saat inaktif, filled saat aktif (tab). Hati dipakai hanya untuk "favorit"/brand, bukan ikon generik.
- **Ilustrasi:** spot-illustration garis tunggal (1.5px, warna `textSecondary` + satu aksen `primary`) digambar dengan `CustomPainter`: amplop (undangan), kalender kecil (date kosong), kamera (memory kosong), awan putus (offline). Tidak ada aset raster baru.
- **Ornamen scrapbook per tema** (`ThemeOrnaments`, baru): selotip, cap, sudut. Lihat §8.
- **Filament:** Heroicons outline (bawaan Filament), satu ikon unik per resource.

---

## 6. Komponen inti (Core) — dipakai semua tema

| Komponen | Isi | Menggantikan |
|---|---|---|
| `AppScaffold` | Scaffold + `ThemedBackground` opsional + batas lebar konten + offline banner | Scaffold per layar |
| `AppShell` | Bottom nav 4 tab (`StatefulShellRoute`) | Daftar tombol di Home |
| `SectionHeader` | overline + title + aksi "See all" | Text ad-hoc |
| `JournalCard` | Kartu dengan radius/border/elevation dari tema, press-scale | `Card + InkWell + Padding` duplikat |
| `StatusChip` | `planned / completed / cancelled / protected / pending / failed` → warna semantik + ikon + label (tidak hanya warna) | `status.toUpperCase()` |
| `DateBadge` | Stub tiket: hari besar + bulan overline | Format tanggal manual |
| `CoupleAvatars` | Dua lingkaran inisial bertumpuk + hati kecil | — |
| `PolaroidFrame` | Bingkai `paper`, foto `photoRadius`, caption handwriting, rotasi kecil deterministik (±1.5°, dari id) | Varian "polaroid" lama |
| `AppStateView` | `loading` (skeleton) · `empty` (ilustrasi + 1 CTA) · `error` (pesan + Retry) · `offline` | ≥ 8 implementasi berbeda |
| `SettingsGroup` / `SettingsTile` | Grup berlatar `surfaceMuted`, tile 56dp, chevron | ListTile polos |
| `AppButton` (diperluas) | `primary · secondary (tonal) · ghost · destructive`, loading state | Campuran Elevated/Outlined/Filled |
| `ConfirmSheet` | Bottom sheet konfirmasi (aksi destruktif berwarna error, default fokus ke Cancel) | AlertDialog default |
| `AppFormatters` | Format tanggal/relative ("in 3 days", "Today") satu tempat | 3 implementasi manual |

---

## 7. Arsitektur token (kompatibel Phase 7)

```
ThemeDefinition (+ ThemeOrnaments, + optional semantic colors, + handwritingFamily, + radii)
        │
ThemeCustomization (TIDAK berubah; wire format PUT /couple/theme sama)
        │
AppTheme.resolveTokens()  ──►  AppThemeTokens (ThemeExtension, lerp)   ← diperluas
                               ├─ colors: + surfaceMuted, paper, warning, info, on* 
                               ├─ text:   + heading, label, caption, overline, handwriting
                               ├─ shape:  + chipRadius, sheetRadius, photoRadius
                               ├─ elevation: e1/e2/e3 (BoxShadow list, lerp)
                               └─ ornaments: ThemeOrnaments (diskrit)
UserPreferences (lokal, per perangkat): themeMode, reduceMotion  ← sudah ada, tidak diubah
CoupleThemeSettings (server, bersama):  theme key + customization ← sudah ada, tidak diubah
```

- Tidak ada perubahan pada `appearance_controller`, cache, endpoint, atau backend catalog.
- Token baru punya default turunan sehingga tema lama tetap valid tanpa diubah.
- `NavigationStyle` (flat/tinted/elevated) diterapkan juga ke bottom nav.

---

## 8. Karakter per tema (Theme Variants)

| Tema | Kartu | Nav bar | Ornamen kartu kenangan | Bingkai foto | Motion |
|---|---|---|---|---|---|
| Classic Rose (default) | radius 20, border tipis | tinted, indikator pill | Selotip washi blush | Polaroid kertas putih | Fade lembut |
| Sakura | radius 24 | tinted | Selotip pink + kelopak di sudut | Polaroid, caption script | Kelopak jatuh (ambient) |
| Winter Love | radius 18, surface sedikit transparan (frosted) | flat | Cap kepingan salju | Bingkai putih tipis, sudut 8 | Salju turun pelan |
| Midnight | radius 16, border glow `primary` 12% | flat | Bintang kecil | Bingkai gelap, garis glow | Twinkle |
| Vintage Film | radius 6, tanpa border, bayangan | elevated | Cap tanggal oranye gaya kamera analog | Lubang sprocket film di tepi | Grain diam |
| Imperial Winter | radius 12, border ganda emas tipis | elevated | Sudut filigree emas | Passe-partout emas | Drift lambat |
| Cottage | radius 22 | tinted | Stiker bunga kering | Kertas linen | Daun melayang |
| Café | radius 16, kertas kraft | elevated | Label kraft + cap cincin kopi | Kartu kraft | Uap kopi |
| Starry Night | radius 20 | tinted | Bintang emas | Bingkai navy, sudut bintang | Rasi bintang berkedip |

Photo Booth templates sudah dipetakan per tema (`photoBoothTemplates`); UI galeri template memakai urutan itu (tema aktif dulu).

---

## 9. Motion

| Token | Durasi | Kurva | Contoh |
|---|---|---|---|
| `fast` | 120ms | `easeOut` | Press state, chip |
| `base` | 220ms | `easeOutCubic` | Expand, tab switch fade-through |
| `slow` | 360ms | `easeInOutCubic` | Sheet, ganti tema (sudah ada via AnimatedTheme) |
| `ambient` | 6–28s | linear loop | Ornamen latar (sudah ada) |

- Transisi halaman: *fade-through* antar tab, *shared-axis horizontal* untuk push.
- Polaroid: masuk dengan fade + naik 8px (stagger 40ms, maks 6 item).
- **Reduced motion:** bila OS `disableAnimations` *atau* preferensi user "Reduce motion" aktif → semua durasi 0, ambient mati, rotasi polaroid tetap (statis, bukan animasi). Satu helper `context.motion` yang semua komponen pakai.

---

## 10. Struktur navigasi Flutter

Bottom nav 4 tab, tinggi 64 + safe area, label selalu tampil:

1. **Home** — Couple Space
2. **Dates** — Date Planner
3. **Memories** — Timeline (+ akses Photo Booth di app bar & quick action)
4. **Me** — Profile & Settings (Account, Couple, Appearance/Themes, Notifications\*, Storage, Subscription, Privacy & Security, Devices, Support, Log out dengan konfirmasi)

\* "Notifications" berisi preferensi yang ada saja; tanpa push.

FAB kontekstual: Dates → "Plan a date", Memories → "New memory". Photo Booth & Themes dibuka sebagai layar penuh (di luar shell).

### Home (Couple Space), urutan atas → bawah
1. Header: `CoupleAvatars`, "Hasan & Ayu" (display), "Together 412 days" bila `relationship_started_at` ada, kalau tidak "Our space since March 2025"; sapaan sesuai waktu ("Good evening, Hasan").
2. Banner aksi (hanya bila perlu): undang partner / recovery key / tema partner.
3. **Next date** — kartu tiket (`DateBadge` + judul + lokasi + countdown "in 3 days").
4. **From our journal** — carousel polaroid memory terbaru (cover terdekripsi lazy).
5. **Quick actions** — 4 chip: New memory · Plan a date · Photo Booth · Themes.
6. **Recent activity** — 5 item terakhir dari date/memory/comment ("Ayu added 3 photos to *Pantai Sore*").

---

## 11. Filament — "Modern SaaS, clean & elegant"

- **Brand:** `brandName('Our Little Space')`, logo wordmark SVG (light/dark), favicon, `primary` = Rosewood (palet Filament dibangkitkan dari `#B4475F`), `gray` = Stone (netral hangat), `danger` Berry, `warning` Amber, `success` Sage, `info` Dusk. Font Nunito **self-hosted** (`LocalFontProvider`) — tanpa request ke CDN font.
- **Sidebar:** `Overview` (Dashboard, System health) · `People` (Users, Couples) · `Billing` (Subscriptions, Plans, Entitlements, Payment webhooks) · `Content & Appearance` (Themes, Photo Booth templates) · `Storage & Backups` (Photo storage, Storage audit log, Database backups). Sidebar collapsible di desktop, `navigationSort` eksplisit, ikon unik.
- **Dashboard (data nyata):** baris KPI (Users, Couples, Active subscriptions, Storage used) · StorageHealth (sudah ada) · Backup status (umur backup DB terakhir terverifikasi; "Protected" hanya bila backup `verified`) · Failed jobs (tabel `failed_jobs`) · Recent operator activity (`storage_audits`). Hapus `FilamentInfoWidget`.
- **Tabel:** kolom primer tebal, ID sebagai teks sekunder, maksimal ±7 kolom terlihat (sisanya toggleable), `StatusBadge` terpusat (`App\Filament\Support\StatusColors`), filter & search di setiap resource utama, empty state berikon + kalimat jelas, `defaultSort` eksplisit.
- **Form & detail:** `Section` dengan deskripsi, `Grid` 2 kolom di desktop, `Tabs` bila > 3 section (mis. Couple: Overview · Members · Subscription · Storage), helper text pada field yang tidak jelas.
- **Privasi:** tidak ada pratinjau foto di admin; `invite_code` dimask (`••••12AB`) dengan aksi copy ber-audit, atau disembunyikan — dikonfirmasi di Step 5.

---

## 12. Perbandingan karakter Flutter vs Filament

| Elemen | Flutter | Filament |
|---|---|---|
| Warna | Paper + Rosewood + ornamen tema | Stone netral + Rosewood hanya untuk aksi |
| Tipografi | Playfair + Nunito + handwriting | Nunito saja (wordmark Playfair di logo) |
| Kartu | Rounded, polaroid, selotip | Section datar, border 1px |
| Ikon | Material Rounded | Heroicons outline |
| Motion | Lembut, ekspresif, bisa dimatikan | Minimal (bawaan Filament) |
| Prioritas | Emosi & kenangan | Efisiensi operasional |
