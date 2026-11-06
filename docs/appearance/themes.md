# Themes & Customization (Phase 7)

The couple shares one theme. Each partner can also set a few options that apply only on their own device.

## 1. Architecture

| Layer | Where | Role |
|---|---|---|
| Theme definitions | `frontend/lib/core/theme/themes/*.dart` | Config objects (`ThemeDefinition`): palette (light, optional dark), typography, component style, decoration, animation, presets, suggested Photo Booth templates. No per-theme widgets. |
| Registry | `frontend/lib/core/theme/theme_registry.dart` | `byKey()` falls back to `classic_rose` for unknown keys, so an old app never crashes on a theme added later. |
| Tokens | `AppThemeTokens` (a `ThemeExtension`) | The only way UI reads colors, text styles, radii and the decoration state: `context.tokens`. Built by `AppTheme.resolveTokens()` from definition + customization. |
| Decorations | `theme_decorations.dart` | One deterministic `CustomPainter` (seeded), wrapped in `IgnorePointer` + `ExcludeSemantics`. It never moves when system "remove animations", the couple's animation switch, or the device's Reduce motion is on. |
| Catalog (server) | `backend/database/data/appearance_catalog.json` | Shared keys, presets, styles and templates. `php artisan appearance:sync-catalog` upserts it and **never** overrides admin-set `is_active`, `is_premium` or `sort_order`. A Flutter test checks that the app matches this file. |
| Couple setting | `couple_theme_settings` (one row per couple) | `theme_key`, `customization` (preset keys only), `version`, `updated_by`. |

The built-in themes are classic_rose (default, identical to the pre-Phase 7 look), sakura, winter_love, midnight (dark only), vintage_film, imperial_winter, cottage, cafe, and starry_night (dark only).

## 2. API

All routes need `auth:sanctum` and couple membership. Nobody outside the couple can read or write the couple's theme.

- `GET /api/v1/appearance/catalog` returns active themes and templates (admin order).
- `GET /api/v1/couple/theme` returns the current setting, or the default with `version: 0`.
- `PUT /api/v1/couple/theme` takes `{theme_key, customization, based_on_version}`. The theme must be active, and every customization value must be a preset of that theme. Free-form colors and fonts are rejected.
- `DELETE /api/v1/couple/theme/customization?based_on_version=N` keeps the theme and resets its options.

## 3. Conflict rule

Every write carries the version the client last saw. The server updates only `WHERE version = based_on_version`, which is a single conditional UPDATE, so PostgreSQL serialises concurrent writers. The first insert for a couple runs in its own savepoint.

A stale write gets **409** with the current setting. The app then shows what the partner picked, and the user decides again. Nothing is silently overwritten, and there is no last-write-wins.

## 4. Sync to the partner

Phase 3 has no couple push channel, so there is no push. Instead:

- the app refreshes on login and on every resume;
- the last known setting is cached in SharedPreferences and applied before the first frame, so the app opens in the couple's theme even offline;
- when the server version is newer and `updated_by` is the partner, a dismissible banner says the partner changed the theme.

Apply is confirmed, not optimistic: the theme changes only after the server accepted it.

## 5. Couple vs. device settings

| Shared by the couple (server) | Only this device (SharedPreferences) |
|---|---|
| Theme, accent, background, font, decorations on/off, animations on/off, Couple Space style, Memory style | Light / dark / system mode, Reduce motion |

On logout, the cached couple setting and the seen version are cleared. Device preferences stay.

## 6. Accessibility

- Every non-legacy theme meets WCAG AA (4.5:1) for body text and button text in each palette and accent preset. `test/core/theme/built_in_themes_test.dart` enforces this.
- **Legacy note:** `classic_rose` keeps the exact pre-Phase 7 colors, so existing users see no change. Its secondary text and primary button are below 4.5:1. The test records the current values so they can't get worse unnoticed. Raising them is a product decision for a later phase.
- Decorations are excluded from semantics and never take taps.

## 7. Admin (Filament)

The Themes and Photo Booth Templates resources can rename, activate or deactivate, mark premium, and reorder items, with no delete. Keys and option lists come from the catalog file and are not editable in the panel. The list shows only an aggregate count of couples using each theme, never which couples. There is no photo data anywhere in these resources.

The panel requires `is_admin === true`.

## 8. Fonts

All fonts are bundled (OFL 1.1), with no runtime download: Nunito, Playfair Display, Cormorant Garamond, Lora, Courier Prime, Dancing Script, and Quicksand. Their licenses are in `frontend/assets/fonts/licenses/` and registered in the app's license page (`registerFontLicenses()`). Variable fonts get their weight through `FontVariation('wght')`.

## 9. Adding a theme

1. Add a `ThemeDefinition` in `themes/`, and list it in `built_in_themes.dart`.
2. Add the same key and preset keys to `appearance_catalog.json`.
3. Run `php artisan appearance:sync-catalog`. A new key is created `active` at its catalog `sort_order`. After that, status, premium, order and display name belong to the admin and are never overwritten by the sync.
4. Run `flutter test test/core/theme`. It checks contrast and consistency with the catalog.

## 10. Verification

- Backend: `tests/Feature/Api/V1/Appearance/CoupleThemeTest.php` covers membership, preset validation, the 409 conflict, reset, the catalog, and sync not overriding admin flags.
- Flutter: `test/core/theme/*` and `test/features/appearance/*` cover tokens, contrast, the catalog match, the controller (offline cache, conflict, partner banner, logout), and the gallery and detail UI.
