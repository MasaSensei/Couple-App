# Photo Booth (Phase 7)

Couples combine photos into a print (2, 3, or 4 frames, a strip, a polaroid, and so on), add a short text and a date, then save it to a Memory or share it.

## 1. Privacy rules (from the Phase 7 spec) and how they are met

| Rule | How |
|---|---|
| Originals never reach the server in plaintext | Photos are picked into memory on the device. The server has no Photo Booth endpoint. |
| The server cannot see or process photo content | Rendering happens on the device (`PhotoBoothRenderer` on a Flutter `Canvas`). The server only ever receives the finished print, encrypted. |
| Editing and rendering on the device | Preview and export use the **same** renderer. A test checks that they match pixel for pixel. |
| Result encrypted before upload | Save to Memory calls `MemoryPhotoNotifier.uploadPhotoBytes`, the Phase 5 pipeline: prepare (EXIF-free JPEG, max 2048 px) → AES-256-GCM with the Couple Key → verify round trip → upload ciphertext → server checks the checksum. |
| Memory photos | Downloaded as ciphertext, decrypted locally (`getDecryptedPhotoBytes`). Photos that fail verification are skipped, never shown. |
| No sensitive metadata in API or logs | The upload has the same metadata as any memory photo (size, dimensions, key id, nonce, mac, checksum). The caption is only inside the encrypted image. A test checks that the photo booth and appearance code has no `print`, `debugPrint`, or `log` calls. |
| No public URL, no admin preview | No new endpoints or storage paths. The print is a normal memory photo, served only by the authenticated `/memory-photos/{id}/content` (ciphertext). Filament has no photo resource. |

## 2. Flow

```
gallery (image_picker) ─┐
                        ├─► PhotoBoothDocument (in memory) ─► PhotoBoothPreview (screen)
memory (decrypt local) ─┘                │
                                         ▼
                            PhotoBoothExportService (PNG, long side 2048)
                                │                         │
                    Save to Memory                       Share
       prepare → encrypt → verify → upload       system share sheet (plaintext,
            (Phase 5 pipeline)                   by the user's explicit choice)
```

## 3. Templates

Templates are data in canvas units (`photo_booth_templates.dart`): slots, frame style, paper and ink colors, and the caption area. They are not hard-coded widgets. The same keys exist in `appearance_catalog.json`, so an admin can deactivate a template. The app shows only templates the server lists, or all built-in ones when offline. Each theme suggests its own templates, and those are shown first.

Photos fill their slot with a centered cover crop, with no distortion. A missing or unreadable photo leaves an empty, styled slot.

## 4. Memory use

- Each photo is decoded at the size its slot needs (`ImageDescriptor` with a target size), not at full camera resolution. Four 12 MP photos decode to about 1 MP each.
- At most 8 photos are held at once.
- Every `ui.Image` and codec is disposed after export.

## 5. Sharing (plaintext caveat)

Share is the one path where an unencrypted image leaves the app, and only because the user chose it. The screen says so under the button.

`share_plus` writes the PNG to a temporary file in the app's cache to hand it to the share sheet. The OS cleans that cache, but until then it exists on the device's own storage, which is the same trust level as the gallery photos the user started from. Nothing is sent to our server.

The `image_picker` cache copy of gallery photos is deleted right after reading (best effort).

## 6. Verification

- `test/features/photo_booth/photo_booth_render_test.dart` covers the template geometry, the cover crop, the decode size, the output size, every template with 0, some, and all photos, an unreadable photo, preview equal to export, 12 MP inputs, and the match with the catalog.
- `test/features/photo_booth/photo_booth_controller_test.dart` checks that:
  - the uploaded bytes are not PNG or JPEG;
  - the uploaded bytes do not contain the caption;
  - the uploaded bytes decrypt with the couple key to an EXIF-free JPEG;
  - a failed upload keeps the editor;
  - share goes only to the share sheet;
  - an empty print is refused;
  - there is no logging and no URL or API use in the photo booth code.
- `test/features/photo_booth/photo_booth_screen_test.dart` covers the empty state, the server template filter, and enabling the buttons.
- Server side, the existing `EncryptionSecurityTest` already proves that stored objects and DB rows hold no plaintext for any memory photo, which includes prints.
