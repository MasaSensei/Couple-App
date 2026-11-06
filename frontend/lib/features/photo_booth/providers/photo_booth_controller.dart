import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/security/encryption_errors.dart';
import 'package:frontend/features/memories/providers/memory_photo_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/photo_booth_document.dart';
import '../domain/photo_booth_template.dart';
import '../domain/photo_booth_templates.dart';
import '../render/photo_booth_export_service.dart';
import '../render/photo_booth_renderer.dart';

/// Shares a finished print through the platform share sheet. Sharing is the
/// one path where plaintext leaves the app, and only because the user chose it.
abstract interface class PhotoBoothSharer {
  Future<void> share(Uint8List png);
}

class SystemPhotoBoothSharer implements PhotoBoothSharer {
  const SystemPhotoBoothSharer();

  @override
  Future<void> share(Uint8List png) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png')],
        fileNameOverrides: const ['photo-booth.png'],
      ),
    );
  }
}

final photoBoothSharerProvider = Provider<PhotoBoothSharer>(
  (ref) => const SystemPhotoBoothSharer(),
);

final photoBoothExportServiceProvider = Provider<PhotoBoothExportService>(
  (ref) => const PhotoBoothExportService(),
);

final photoBoothControllerProvider =
    NotifierProvider.autoDispose<PhotoBoothController, PhotoBoothState>(
      PhotoBoothController.new,
    );

enum PhotoBoothBusy { none, exporting, saving, sharing }

@immutable
class PhotoBoothState {
  const PhotoBoothState({
    required this.document,
    this.busy = PhotoBoothBusy.none,
  });

  final PhotoBoothDocument document;
  final PhotoBoothBusy busy;

  PhotoBoothState copyWith({
    PhotoBoothDocument? document,
    PhotoBoothBusy? busy,
  }) => PhotoBoothState(
    document: document ?? this.document,
    busy: busy ?? this.busy,
  );
}

/// Thrown with a message that is safe to show the user.
class PhotoBoothException implements Exception {
  const PhotoBoothException(this.message);

  final String message;
}

/// Editor state for one print. Everything happens on the device: photos are
/// plaintext only in memory here, and leave either encrypted (save to
/// Memory, through the Phase 5 pipeline) or by explicit user share.
class PhotoBoothController extends Notifier<PhotoBoothState> {
  /// Upper bound on photos held at once, so a large selection cannot exhaust memory.
  static const maxPhotos = 8;

  int _nextId = 0;

  @override
  PhotoBoothState build() => PhotoBoothState(
    document: PhotoBoothDocument(
      template: PhotoBoothTemplates.classic3,
      date: DateTime.now(),
    ),
  );

  PhotoBoothDocument get _doc => state.document;

  void setTemplate(PhotoBoothTemplate template) =>
      _set(_doc.copyWith(template: template));

  void addPhotos(List<Uint8List> photos, PhotoSourceKind source) {
    final room = maxPhotos - _doc.photos.length;
    if (room <= 0) return;

    _set(
      _doc.copyWith(
        photos: [
          ..._doc.photos,
          for (final bytes in photos.take(room))
            PhotoBoothPhoto(id: 'p${_nextId++}', bytes: bytes, source: source),
        ],
      ),
    );
  }

  void removePhoto(String id) => _set(
    _doc.copyWith(photos: _doc.photos.where((p) => p.id != id).toList()),
  );

  /// `onReorderItem` semantics: [newIndex] is already adjusted for the removal.
  void reorder(int oldIndex, int newIndex) {
    final photos = [..._doc.photos];
    final moved = photos.removeAt(oldIndex);
    photos.insert(newIndex.clamp(0, photos.length), moved);
    _set(_doc.copyWith(photos: photos));
  }

  void setCaption(String caption) {
    final trimmed = caption.length > PhotoBoothDocument.maxCaptionLength
        ? caption.substring(0, PhotoBoothDocument.maxCaptionLength)
        : caption;
    _set(_doc.copyWith(caption: trimmed));
  }

  void setShowDate(bool value) => _set(_doc.copyWith(showDate: value));

  void setDate(DateTime date) => _set(_doc.copyWith(date: date));

  /// Renders, then encrypts and uploads through the same pipeline as any
  /// Memory photo (prepare → encrypt → verify round-trip → upload → server
  /// checksum). Throws [PhotoBoothException].
  Future<void> saveToMemory({
    required int memoryId,
    required Color accent,
  }) async {
    final export = await _export(accent, PhotoBoothBusy.saving);

    try {
      await ref
          .read(memoryPhotoNotifierProvider.notifier)
          .uploadPhotoBytes(memoryId: memoryId, bytes: export.bytes);
    } on PhotoUploadException catch (error) {
      throw PhotoBoothException(error.message);
    } catch (_) {
      throw const PhotoBoothException(EncryptionMessages.uploadFailed);
    } finally {
      state = state.copyWith(busy: PhotoBoothBusy.none);
    }
  }

  Future<void> share({required Color accent}) async {
    final export = await _export(accent, PhotoBoothBusy.sharing);

    try {
      await ref.read(photoBoothSharerProvider).share(export.bytes);
    } catch (_) {
      throw const PhotoBoothException(
        "We couldn't open the share sheet. Please try again.",
      );
    } finally {
      state = state.copyWith(busy: PhotoBoothBusy.none);
    }
  }

  Future<PhotoBoothExport> _export(Color accent, PhotoBoothBusy busy) async {
    if (state.busy != PhotoBoothBusy.none) {
      throw const PhotoBoothException('Please wait a moment.');
    }
    if (_doc.photos.isEmpty) {
      throw const PhotoBoothException('Add at least one photo first.');
    }

    state = state.copyWith(busy: busy);

    try {
      final service = ref.read(photoBoothExportServiceProvider);
      return await PhotoBoothExportService(
        longSide: service.longSide,
        renderer: PhotoBoothRenderer(accent: accent),
      ).export(_doc);
    } catch (_) {
      state = state.copyWith(busy: PhotoBoothBusy.none);
      throw const PhotoBoothException(
        "We couldn't create the picture. Please try again.",
      );
    }
  }

  void _set(PhotoBoothDocument document) =>
      state = state.copyWith(document: document);
}
