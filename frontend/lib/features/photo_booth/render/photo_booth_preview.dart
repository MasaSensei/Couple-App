import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../domain/photo_booth_document.dart';
import 'photo_booth_export_service.dart';
import 'photo_booth_renderer.dart';

/// Live preview of a print, painted by the same [PhotoBoothRenderer] as the
/// export. Photos are decoded at preview size only, then disposed.
///
/// With [onFramingChanged], each filled slot can be adjusted like a picture in
/// a frame: drag to move, pinch to zoom, double-tap to re-centre. A touch that
/// starts on a photo belongs to the photo; the page scrolls from anywhere else.
class PhotoBoothPreview extends StatefulWidget {
  const PhotoBoothPreview({
    super.key,
    required this.document,
    this.renderer = const PhotoBoothRenderer(),
    this.onFramingChanged,
  });

  final PhotoBoothDocument document;
  final PhotoBoothRenderer renderer;

  /// Called once per gesture, when the finger lifts. Null: read-only preview.
  final void Function(String photoId, PhotoFraming framing)? onFramingChanged;

  @override
  State<PhotoBoothPreview> createState() => _PhotoBoothPreviewState();
}

class _PhotoBoothPreviewState extends State<PhotoBoothPreview> {
  static const _doubleTapWindow = Duration(milliseconds: 300);
  static const _tapSlop = 4.0;

  List<ui.Image?> _images = const [];
  String? _decodedFor;

  /// Canvas units → logical pixels, from the last layout.
  double _scale = 1;

  // The gesture in progress. The draft is painted locally and only committed
  // on release, so the screen above does not rebuild on every frame.
  int? _activeSlot;
  PhotoFraming? _draft;
  PhotoFraming _startFraming = PhotoFraming.centered;
  Offset _startFocal = Offset.zero;
  bool _moved = false;
  DateTime? _lastTapAt;
  int? _lastTapSlot;

  bool get _interactive => widget.onFramingChanged != null;

  @override
  void dispose() {
    _disposeImages(_images);
    super.dispose();
  }

  void _disposeImages(List<ui.Image?> images) {
    for (final image in images) {
      image?.dispose();
    }
  }

  Future<void> _ensureDecoded(double pixelWidth) async {
    // Mid-gesture the current decode is reused; zoom sharpness catches up on release.
    if (_draft != null) return;

    final document = widget.document;
    // Re-decode only when the photos, their order or zoom, the layout or the size change.
    final photos = document.slotted
        .map((p) => '${p.id}@${p.framing.zoom.toStringAsFixed(1)}')
        .join(',');
    final signature =
        '${document.template.key}|$photos|${pixelWidth.round()}';
    if (signature == _decodedFor) return;
    _decodedFor = signature;

    final images = await PhotoBoothExportService.decodeForSlots(
      document,
      pixelWidth / document.template.canvasSize.width,
    );

    if (!mounted || signature != _decodedFor) {
      _disposeImages(images);
      return;
    }

    final old = _images;
    setState(() => _images = images);
    _disposeImages(old);
  }

  /// The document as painted: the committed one plus the gesture's draft.
  PhotoBoothDocument get _painted {
    final slot = _activeSlot;
    final draft = _draft;
    final document = widget.document;
    if (slot == null || draft == null || slot >= document.photos.length) {
      return document;
    }

    final photos = [...document.photos];
    photos[slot] = photos[slot].copyWith(framing: draft);
    return document.copyWith(photos: photos);
  }

  /// The filled, decoded slot under [local] (logical pixels), if any.
  int? _slotAt(Offset local) {
    final point = local / _scale;
    final slots = widget.document.template.slots;
    final filled = widget.document.slotted.length;

    for (var i = 0; i < slots.length && i < filled; i++) {
      if (slots[i].contains(point) && _imageAt(i) != null) return i;
    }
    return null;
  }

  ui.Image? _imageAt(int slot) => slot < _images.length ? _images[slot] : null;

  /// A touch on a photo (or a second finger during an adjustment) is ours.
  bool _claims(Offset local) => _activeSlot != null || _slotAt(local) != null;

  void _onScaleStart(ScaleStartDetails details) {
    final slot = _slotAt(details.localFocalPoint);
    if (slot == null) return;

    final image = _imageAt(slot)!;
    final framing = widget.document.slotted[slot].framing;
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());

    setState(() {
      _activeSlot = slot;
      // Start from the framing as actually shown (it may have been clamped
      // after a layout change), so the first move does not jump.
      _startFraming = framing.copyWith(
        focus: PhotoBoothRenderer.clampFocus(
          imageSize,
          widget.document.template.slots[slot].size,
          framing,
        ),
      );
      _draft = _startFraming;
      _startFocal = details.localFocalPoint;
      _moved = false;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final slot = _activeSlot;
    if (slot == null) return;

    final image = _imageAt(slot);
    if (image == null) return;

    final pan = details.localFocalPoint - _startFocal;
    if (pan.distance > _tapSlop || (details.scale - 1).abs() > 0.02) {
      _moved = true;
    }

    final slotSize = widget.document.template.slots[slot].size;
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final zoomed = _startFraming.copyWith(
      zoom: _startFraming.zoom * details.scale,
    );

    // The photo follows the finger: moving it right shows more of its left,
    // so the focus moves the other way, by the crop's share of the photo.
    final crop = PhotoBoothRenderer.framedSourceRect(
      imageSize,
      slotSize,
      zoomed,
    );
    final slotOnScreen = slotSize * _scale;
    final focus = Offset(
      _startFraming.focus.dx -
          pan.dx / slotOnScreen.width * (crop.width / imageSize.width),
      _startFraming.focus.dy -
          pan.dy / slotOnScreen.height * (crop.height / imageSize.height),
    );
    final next = zoomed.copyWith(focus: focus);

    setState(() {
      _draft = next.copyWith(
        focus: PhotoBoothRenderer.clampFocus(imageSize, slotSize, next),
      );
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final slot = _activeSlot;
    final draft = _draft;
    if (slot == null || draft == null) return;

    final photo = widget.document.slotted[slot];
    var result = draft;

    if (!_moved) {
      final now = DateTime.now();
      final isDoubleTap =
          _lastTapSlot == slot &&
          _lastTapAt != null &&
          now.difference(_lastTapAt!) <= _doubleTapWindow;
      _lastTapAt = isDoubleTap ? null : now;
      _lastTapSlot = slot;
      result = isDoubleTap ? PhotoFraming.centered : photo.framing;
    }

    setState(() {
      _activeSlot = null;
      _draft = null;
    });

    if (result != photo.framing) {
      widget.onFramingChanged?.call(photo.id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.document.template;
    final document = _painted;

    return AspectRatio(
      aspectRatio: template.aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _scale = constraints.maxWidth / template.canvasSize.width;
          _ensureDecoded(
            constraints.maxWidth * MediaQuery.devicePixelRatioOf(context),
          );

          final size = Size(
            constraints.maxWidth,
            constraints.maxWidth / template.aspectRatio,
          );

          Widget preview = RepaintBoundary(
            child: CustomPaint(
              size: size,
              painter: _PhotoBoothPainter(
                widget.renderer,
                document,
                _images,
              ),
              foregroundPainter: _activeSlot == null
                  ? null
                  : _SlotOutlinePainter(
                      template.slots[_activeSlot!],
                      _scale,
                      template.slotRadius,
                      Theme.of(context).colorScheme.primary,
                    ),
            ),
          );

          if (_interactive) {
            preview = RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                _PhotoScaleGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      _PhotoScaleGestureRecognizer
                    >(
                      () => _PhotoScaleGestureRecognizer(claims: _claims),
                      (recognizer) => recognizer
                        ..claims = _claims
                        ..onStart = _onScaleStart
                        ..onUpdate = _onScaleUpdate
                        ..onEnd = _onScaleEnd,
                    ),
              },
              child: preview,
            );
          }

          final filled = widget.document.slotted.length;
          return Semantics(
            image: true,
            label:
                '${template.name} preview with $filled of ${template.photoCount} photos',
            hint: _interactive && filled > 0
                ? 'Drag a photo to move it, pinch to zoom, double-tap to re-centre'
                : null,
            child: preview,
          );
        },
      ),
    );
  }
}

/// A scale recognizer that wins the gesture arena at once when the touch
/// starts on a photo, so the surrounding scroll view does not steal a
/// vertical drag. Touches elsewhere compete normally and the page scrolls.
class _PhotoScaleGestureRecognizer extends ScaleGestureRecognizer {
  _PhotoScaleGestureRecognizer({required this.claims});

  bool Function(Offset local) claims;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    if (claims(event.localPosition)) {
      resolvePointer(event.pointer, GestureDisposition.accepted);
    }
  }
}

class _PhotoBoothPainter extends CustomPainter {
  _PhotoBoothPainter(this.renderer, this.document, this.images);

  final PhotoBoothRenderer renderer;
  final PhotoBoothDocument document;
  final List<ui.Image?> images;

  @override
  void paint(Canvas canvas, Size size) =>
      renderer.paint(canvas, size, document, images);

  @override
  bool shouldRepaint(covariant _PhotoBoothPainter old) =>
      old.document != document ||
      old.images != images ||
      old.renderer.accent != renderer.accent;
}

/// Marks the slot being adjusted. Preview only; never part of the export.
class _SlotOutlinePainter extends CustomPainter {
  _SlotOutlinePainter(this.slot, this.scale, this.radius, this.color);

  final Rect slot;
  final double scale;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      slot.left * scale,
      slot.top * scale,
      slot.right * scale,
      slot.bottom * scale,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius * scale)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SlotOutlinePainter old) =>
      old.slot != slot ||
      old.scale != scale ||
      old.radius != radius ||
      old.color != color;
}
