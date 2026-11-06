# Photo Encryption (Phase 5)

Internal security note. Contains no real keys.

**Claim we make:** photos are encrypted before they leave the user's device, and the server does not hold the keys needed to decrypt them.

**Claim we do not make:** "photos can never leak". See [Limitations](#limitations).

## 1. Threat model

### Protected against

These parties can read everything on the server side but still cannot see photo contents:

| Party | What they get | Why it is not enough |
|---|---|---|
| Database administrator / DB dump | `memory_photos` metadata, `couple_key_packages`, `couple_key_recovery_packages`, device public keys | Every key in the database is encrypted with a device private key or a Recovery Key, and neither ever reaches the server |
| Storage administrator / bucket leak | Encrypted blobs (`application/octet-stream`) | AES-256-GCM ciphertext |
| Laravel / Filament administrator | Same as above. There is no preview, download, or decrypt action | The server never handles a plaintext key |
| Backups | Copies of DB + storage | Same as above |
| Accidental server access, log readers | Logs | Logs never contain photos, keys, Recovery Keys, or payloads |

### Not protected against

- Someone using an unlocked phone where the app is already signed in.
- Malware or a compromised OS on a user's phone.
- Screenshots, screen recording, or a camera pointed at the screen.
- A user or partner who shares a photo deliberately.
- A partner's device: by design it holds the Couple Key.
- Copies already decrypted or cached on a device that is later revoked.
- Metadata visible to the server: who uploaded, when, which memory, ciphertext size, approximate image dimensions, and the couple relationship.
- **A malicious server operator who changes the app's server code.** That operator could:
  - insert a fake device and wait for someone to approve it. This is mitigated by device fingerprint confirmation, see §5.
  - send a newly installed device a key package for a key the attacker knows. This is mitigated partially: a device never replaces a key it already trusts. Signing key packages is future work.

## 2. Algorithms

All cryptography comes from the [`cryptography`](https://pub.dev/packages/cryptography) package. On Android and iOS, `cryptography_flutter` registers itself automatically and switches to native platform implementations. We wrote no cryptographic primitives ourselves.

| Purpose | Algorithm |
|---|---|
| Photo encryption | AES-256-GCM, 96-bit random nonce, 128-bit tag |
| Per-photo key | HKDF-SHA256(Couple Key, photo id) |
| Wrapping the Couple Key for a device | X25519 ephemeral ECDH, then HKDF-SHA256, then AES-256-GCM |
| Wrapping the Couple Key for recovery | AES-256-GCM using a 256-bit random Recovery Key |
| Storage integrity | SHA-256(ciphertext) |
| Device fingerprint | First 80 bits of SHA-256(device public key) |

Associated data (AAD) binds each piece of ciphertext to its context:
- photos: `key_id:version:photo_id`
- device packages: `key_id:version`
- recovery packages: `couple-key-recovery-v1:key_id`

A blob cannot be moved to another photo or to another key slot without failing authentication.

**Checksum ≠ authentication.** The server checks SHA-256(ciphertext) and the size when an upload completes, to catch storage corruption. The client verifies the AES-GCM tag before it uses any plaintext. If verification fails, nothing is displayed.

## 3. Key hierarchy

```
Device private key (X25519)          one per device, in Keychain / Android Keystore-backed storage
        │ unwraps
        ▼
Couple Key (256-bit)                 one per couple, identified by key_id
        │ HKDF(photo_id)
        ▼
Photo key (256-bit)                  derived on demand, never stored
        │ AES-256-GCM
        ▼
Encrypted photo blob

Recovery Key (256-bit)  ──wraps──►  Couple Key   (recovery package, one per user)
```

What the server stores:
- `user_devices.public_key`
- `couple_key_packages`: the Couple Key encrypted for one device
- `couple_key_recovery_packages`: the Couple Key encrypted with a user's Recovery Key
- photo metadata: `encryption_version`, `encryption_algorithm`, `key_id`, `nonce`, `mac`, `encrypted_size`, `checksum`

It does not store plaintext keys, the Recovery Key, or file names.

What the device stores: its private key and the Couple Key, both in `flutter_secure_storage` (iOS Keychain, Android Keystore-encrypted storage). Neither is kept in SharedPreferences, SQLite, or plain files.

The user's password only authenticates them to the API. It plays no part in any key derivation, so a password reset does not give anyone the ability to decrypt.

## 4. Key lifecycle

1. **Initialization.** The couple's first device generates the Couple Key on the device. It wraps the key for itself and uploads the package. The local key is saved only after the server accepts the package. The server allows only one `key_id` per couple and answers `409` to a second one. That prevents two partners from creating different keys at the same time.
2. **Partner joins.** The partner's device registers its public key. It finds that the couple already has a key, so it does not create one. It shows *"Unlock your private photos"* together with its fingerprint. A device that already has access lists it under *My Devices → waiting for access*. The user checks that the codes on both screens match, then approves. The approving device wraps the Couple Key for the new device's public key.
3. **Upload:** prepare (validate, apply orientation, resize to a maximum of 2048 px, strip EXIF/ICC/text, re-encode as JPEG q85), then create an upload session, then encrypt (the photo id goes into the key derivation and the AAD), then send the metadata (`PATCH /memory-photos/{id}/encryption`), then upload the ciphertext, then call `complete`. The server checks size and SHA-256 and marks the photo `verified`. The server rejects:
   - binary uploads that arrive before encryption metadata exists
   - metadata that refers to a `key_id` the couple does not have
4. **Download:** fetch the ciphertext, then check size and checksum, then verify the AES-GCM tag and decrypt, then display.
   - If verification fails: *"We couldn't verify this photo."*
   - If the device does not have the key: *"This device doesn't have the key needed to open this photo."*

## 5. Devices

- Each device has its own X25519 key pair. The private key never leaves the device. Tests check this on both the client and the server.
- Registering a device binds the current API token to it (`personal_access_tokens.user_device_id`).
- **Revocation** (`DELETE /devices/{id}`):
  - marks the device revoked
  - revokes its key packages
  - deletes the tokens bound to it, so the revoked device gets `401` from then on
  - a revoked `device_identifier` can never register again. The app then wipes its local keys and joins as a new device, which needs approval again.
- If a device registers again with a different public key, its old packages are revoked.
- **Limitation:** revocation cannot erase photos or the Couple Key that are already on the revoked device. Someone who keeps that device and its key could still decrypt ciphertext they obtain some other way. Fully cutting it off requires key rotation (§7).

## 6. Recovery

- The Recovery Key is 256 random bits. It is shown as 13 groups of 4 Base32 characters, for example `ABCD-EFGH-…`.
- Setup screen: intro, *Generate*, *Tap to reveal*, *Copy* (the app clears the clipboard after 60 s), the checkbox *"I have safely stored my recovery key"*, then the user re-enters the key to verify it. Only after that is the encrypted recovery package uploaded. The app never shows the key again.
- Restore on a new device: enter the Recovery Key. The app downloads the package and decrypts it locally, saves the Couple Key, then wraps it for the new device.
- Each user has their own Recovery Key and their own package.

**Trade-off, by design:** more privacy means less ability to recover on the server side. If a user loses every device that has access, has no partner device that can approve them, and has lost the Recovery Key, **the photos cannot be recovered by anyone, including us.** This is covered by a test, scenario B.

## 7. Rotation (foundation only)

Every photo and every package carries a `key_id`, and every format carries a version. A future rotation would work like this:
1. A device generates a new Couple Key and wraps it for all active devices.
2. New photos use the new `key_id`.
3. Old photos keep their old `key_id` until a background job re-encrypts them on the client. Re-encryption must never be synchronous.

The server currently enforces one `key_id` per couple (`shortcut:` comment in `CoupleKeyPackageService`). Rotation needs an explicit endpoint that retires the old key.

## 8. Storage model

- Objects live on the private `local` disk (`storage/app/private`) and are never public.
- Content is served only through `GET /memory-photos/{id}/content`. That endpoint requires authentication and couple membership, returns `application/octet-stream`, and sends `Cache-Control: private, no-store` and `nosniff`.
- Encrypted objects are still kept private, because exposing them would leak metadata and invite abuse.

## 9. Admin

Filament has no photo resource. That means no preview, no download, no decrypt action, and no access to keys or recovery material. A future metadata-only view may show: photo id, memory id, couple id, encrypted size, version, key id, checksum, status, created_at.

## 10. Known limitations / follow-ups

- `image_picker` copies the selected photo into the app's cache. We never write our own plaintext temp files: preparation and encryption happen in memory. The picker's cached copy, however, is left for the OS to clean up.
- Key packages are not signed by the sender, so a freshly installed device trusts the first package the server gives it (trust on first use).
- Photos stuck in `pending`, `uploading`, or `failed` are moved to the trash after 24 h and purged by retention (see `docs/storage/reliability.md` §13).
- The Recovery Key setup and restore screens set `FLAG_SECURE` on Android (no screenshots, screen recording, or recents thumbnail). iOS has no equivalent API, so screenshots there are not blocked.
- There is no export of the Recovery Key beyond Copy, which is cleared after 60 s. Users should write it down or store it in a password manager.

## 11. Verification

- Backend: `tests/Feature/Api/V1/Security/EncryptionSecurityTest.php`. It searches every DB table and every storage object for the couple, photo, recovery, and device keys and for the plaintext, in raw, Base64, Base64url, and hex forms. It also covers: partner decrypt, outsider `403`, checksum mismatch, unknown `key_id`, partner key sharing, the one-key-per-couple rule, revocation (token `401`, re-register `403`), and recovery package privacy.
- Flutter: `test/core/security/couple/couple_key_provisioning_service_test.dart` simulates multiple devices against a fake server. It covers:
  - partner approval followed by decrypt
  - no second key created
  - a server key swap is refused
  - recovery scenarios A, B, and C
  - wrong key fails
- Flutter: `memory_photo_repository_decrypt_test.dart` covers tampered ciphertext, a tampered tag, a truncated download, and the wrong key.
- Flutter: `photo_preparation_service_test.dart` checks that EXIF and GPS data are removed, along with resizing and rejection of invalid input.
