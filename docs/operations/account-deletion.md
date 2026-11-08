# Account deletion & data export

Required by Apple (App Store Review Guideline 5.1.1(v): apps with account
creation must offer in-app account deletion) and Google Play (account deletion
in the app **and** a web link/form), and by GDPR (erasure, access, portability).
Re-check both stores' current wording before submission.

## In-app

Home → **Account & data** (`AccountScreen`):

- **Export my data** → `GET /api/v1/me/export` → JSON shared via the OS share sheet: profile, devices, couple members, dates, memories with photo metadata, the user's own comments. Photo bytes stay encrypted on the server; the user saves decrypted copies from the app. (A full "decrypted ZIP" export is a follow-up.)
- **Delete account** → dialog explaining consequences, password + "I understand" checkbox → `DELETE /api/v1/me` → local token cleared → login screen.

## What deletion does (`AccountService::delete`)

| Data | Partner remains | User was the last member |
|---|---|---|
| Profile, email, password hash | deleted now | deleted now |
| API tokens, sessions, devices, device key packages, recovery package | deleted now | deleted now |
| Own date/memory comments | deleted now | deleted now |
| Memories, photos, dates of the shared space | **stay with the partner**, author set to NULL (shown as a former member) | memories & dates deleted; photos moved to the trash → existing purge removes the primary copy after 30 days and the backup copy 30 days later (≈ 60 days total, object-lock bound) |
| Couple subscription | stays with the couple | deletion **blocked** while a store subscription auto-renews ("turn off auto-renew first"); store billing cannot be stopped by us |
| Admin audit / billing transactions | kept, user reference set to NULL (financial records, legal retention) | same |
| Encrypted DB backups | contain the account until they expire (30 days, immutable) | same — disclosed in the privacy policy |
| Logs | request logs contain `user_id`/IP, retained 30 days | same |

Why shared content stays with the partner: memories belong to the couple's
shared space; deleting one account must not destroy the other person's memories.
The departing user's devices keep a copy of the Couple Key they already had
(no rotation yet — security.md S12).

Password confirmation + the `auth` rate limit protect against deletion with a
stolen token alone and against password guessing through this endpoint.

## Evidence

`tests/Feature/Account/AccountDeletionTest.php` (7 tests): wrong password deletes
nothing; partner keeps photos/dates with anonymised author and still reads them
through the API; last member → trash → purge queued after retention; renewing
store subscription blocks deletion until cancelled; export content and absence
of secrets (password hash, keys, nonce, MAC, storage keys). Flutter:
`auth_lifecycle_test.dart` (deletion clears credentials, wrong password keeps
session, dialog gating, null authors parse).

## Still to do

- Web deletion page/form (Google Play requires a link usable without the app).
- Grace period / undo (currently immediate).
- Decrypted media export.
