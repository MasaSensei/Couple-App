# Flutter release checklists

Builds are configured per environment with `--dart-define`:

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols \
  --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.<domain>/api/v1 \
  -PappId=<final.application.id> -PstoreRelease=true          # (Gradle properties via --android-project-arg if needed)
flutter build ipa --release --obfuscate --split-debug-info=build/symbols \
  --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.<domain>/api/v1
```

`AppConfig.validate` makes a release or non-dev build **crash at start** if the
URL is not HTTPS or points at `10.0.2.2`/`localhost`, or `APP_ENV` is unknown.

Verified 2026-11-07 (Windows host): `flutter analyze --fatal-infos` clean,
`flutter test` 334 passed, `dart format` clean, `flutter build appbundle --release`
(staging defines) → `app-release.aab` 53.9 MB; merged release manifest:
`usesCleartextTraffic=false`, `allowBackup=false`, only `INTERNET` permission.
iOS was **not** built (needs macOS; CI job `ios` prepared, not yet run).

## Shared (both platforms)

- [ ] Final product name, application id / bundle id chosen (currently placeholder `com.example.frontend` — store uploads are blocked by the Gradle guard until set)
- [ ] `version:` in `pubspec.yaml` bumped (`major.minor.patch+build`; build number strictly increasing per store)
- [ ] Production `API_BASE_URL` live, TLS valid, `/health/ready` green
- [ ] No debug UI in release: mock purchase gateway only in `kDebugMode` (verified), no debug banners (`debugShowCheckedModeBanner: false`)
- [ ] No secrets in the app: CI grep step; only public config via `--dart-define`
- [ ] Crash reporting provider chosen and wired in `CrashReporter.report` (currently **local only**), with `scrub()` applied; upload obfuscation symbols (`build/symbols`)
- [ ] Store billing implemented (`in_app_purchase`) — currently the release build disables purchases with an honest notice
- [ ] Privacy policy + terms URLs live, linked in the app and the store listing
- [ ] Account deletion reachable in ≤ 3 taps (Home → Account & data → Delete) ✔
- [ ] Offline start: app keeps the session and shows "Try again" (verified in tests) ✔
- [ ] Permissions requested only at use (photo picker / camera in Photo Booth)
- [ ] Push notifications: **not implemented** (no FCM/APNs) — no permission prompt shipped
- [ ] Deep links: none in this version (invite codes are typed) — nothing to verify
- [ ] Manual QA on a physical device per platform: register, couple join, key sharing & recovery key, upload/download photo, Photo Booth, themes, delete account

## Android

- [ ] Upload keystore created, stored in the secret store; `android/key.properties` (git-ignored) generated in the release lane; Play App Signing enabled
- [ ] `-PappId=<id>` and `-PstoreRelease=true` (Gradle refuses store bundles with the placeholder id or debug signing)
- [ ] `targetSdk` = current Play requirement (Flutter default today — re-check at release)
- [ ] R8/shrink enabled (release) — run the full manual QA on the minified build (plugins with reflection)
- [ ] Release manifest: no cleartext, no backup, minimal permissions ✔
- [ ] Data safety form (privacy-legal.md §3)
- [ ] Content rating questionnaire; target audience 18+ (couples app, user-generated photos)
- [ ] Store listing: icon 512², feature graphic 1024×500, ≥ 2 phone screenshots, short/long description without unproven security claims
- [ ] Account deletion **web link** (Play requirement) — not built yet
- [ ] Internal testing track → closed testing (Play requires a testing period for new personal developer accounts) → production

## iOS

- [ ] Apple Developer Program, bundle id, distribution certificate + provisioning profile (Xcode automatic signing in the release lane)
- [ ] `Info.plist` usage strings: camera, photo library, photo library add ✔
- [ ] ATS: no arbitrary loads; `NSAllowsLocalNetworking` only (dev) ✔
- [ ] **Export compliance**: the app implements its own encryption (AES-GCM, X25519) for user data. Determine with counsel whether it qualifies for an exemption; set `ITSAppUsesNonExemptEncryption` accordingly and file the annual self-classification report if required. Deliberately **not** set to `false` by default.
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) for required-reason APIs used by the app and plugins (shared_preferences → UserDefaults); check every plugin ships its own
- [ ] App Privacy "nutrition label" (privacy-legal.md §3)
- [ ] Sign in: email/password only → "Sign in with Apple" not required; re-check if social login is added
- [ ] In-app purchase via StoreKit only (no external payment links) once billing ships
- [ ] Screenshots 6.9"/6.5" and iPad if supported; age rating 17+ questionnaire
- [ ] TestFlight internal → external beta → review
- [ ] Note: iOS cannot block screenshots of the Recovery Key screen (documented in encryption.md)
