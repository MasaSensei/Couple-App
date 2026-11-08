import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../domain/photo_booth_document.dart';
import '../domain/photo_booth_template.dart';
import 'photo_booth_renderer.dart';

/// A rendered print: plaintext PNG bytes that live only in app memory until
/// they are encrypted for upload or explicitly shared by the user.
@immutable
class PhotoBoothExport {
  const PhotoBoothExport({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Renders the final image with the same [PhotoBoothRenderer] as the preview.
///
/// Memory stays bounded: every photo is decoded straight to the size of the
/// slot it fills at the output resolution (never at full camera resolution),
/// and every decoded image is disposed as soon as the print is drawn.
class PhotoBoothExportService {
  const PhotoBoothExportService({
    this.longSide = 2048,
    this.renderer = const PhotoBoothRenderer(),
  });

  /// Output size of the long edge. 2048 matches Phase 5's upload preparation,
  /// so a saved print is not downscaled again.
  final int longSide;
  final PhotoBoothRenderer renderer;

  Size outputSize(PhotoBoothTemplate template) {
    final canvas = template.canvasSize;
    final scale = longSide / math.max(canvas.width, canvas.height);

    return Size(
      (canvas.width * scale).roundToDouble(),
      (canvas.height * scale).roundToDouble(),
    );
  }

  Future<PhotoBoothExport> export(PhotoBoothDocument document) async {
    final size = outputSize(document.template);
    final images = await decodeForSlots(
      document,
      size.width / document.template.canvasSize.width,
    );
    ui.Picture? picture;
    ui.Image? rendered;

    try {
      final recorder = ui.PictureRecorder();
      renderer.paint(ui.Canvas(recorder), size, document, images);
      picture = recorder.endRecording();
      rendered = await picture.toImage(size.width.toInt(), size.height.toInt());
      final data = await rendered.toByteData(format: ui.ImageByteFormat.png);

      return PhotoBoothExport(
        bytes: data!.buffer.asUint8List(),
        width: rendered.width,
        height: rendered.height,
      );
    } finally {
      for (final image in images) {
        image?.dispose();
      }
      picture?.dispose();
      rendered?.dispose();
    }
  }

  /// Decodes each slotted photo just large enough to cover its slot at
  /// [scale] (canvas units → pixels), times the photo's zoom so a zoomed-in
  /// crop stays sharp (never above the photo's own resolution).
  /// Unreadable photos become empty slots.
  static Future<List<ui.Image?>> decodeForSlots(
    PhotoBoothDocument document,
    double scale,
  ) async {
    final slots = document.template.slots;

    return Future.wait([
      for (final (i, photo) in document.slotted.indexed)
        _decode(
          photo.bytes,
          Size(slots[i].width, slots[i].height) *
              (scale * photo.framing.zoom),
        ),
    ]);
  }

  /// Target decode size for an [image] filling [slot] with a centre crop.
  static Size decodeTargetSize(Size image, Size slot) {
    final scale = math.max(
      slot.width / image.width,
      slot.height / image.height,
    );
    if (scale >= 1) return image;

    return Size(
      (image.width * scale).ceilToDouble(),
      (image.height * scale).ceilToDouble(),
    );
  }

  static Future<ui.Image?> _decode(Uint8List bytes, Size slot) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;

    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final target = decodeTargetSize(
        Size(descriptor.width.toDouble(), descriptor.height.toDouble()),
        slot,
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: target.width.toInt(),
        targetHeight: target.height.toInt(),
      );

      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
