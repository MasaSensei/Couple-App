import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/photo_booth_document.dart';
import 'photo_booth_export_service.dart';
import 'photo_booth_renderer.dart';

/// Live preview of a print, painted by the same [PhotoBoothRenderer] as the
/// export. Photos are decoded at preview size only, then disposed.
class PhotoBoothPreview extends StatefulWidget {
  const PhotoBoothPreview({
    super.key,
    required this.document,
    this.renderer = const PhotoBoothRenderer(),
  });

  final PhotoBoothDocument document;
  final PhotoBoothRenderer renderer;

  @override
  State<PhotoBoothPreview> createState() => _PhotoBoothPreviewState();
}

class _PhotoBoothPreviewState extends State<PhotoBoothPreview> {
  List<ui.Image?> _images = const [];
  String? _decodedFor;

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
    final document = widget.document;
    // Re-decode only when the photos, their order, the layout or the size change.
    final signature =
        '${document.template.key}|${document.slotted.map((p) => p.id).join(',')}|${pixelWidth.round()}';
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

  @override
  Widget build(BuildContext context) {
    final template = widget.document.template;

    return AspectRatio(
      aspectRatio: template.aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _ensureDecoded(
            constraints.maxWidth * MediaQuery.devicePixelRatioOf(context),
          );

          return Semantics(
            image: true,
            label:
                '${template.name} preview with ${widget.document.slotted.length} of ${template.photoCount} photos',
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size(
                  constraints.maxWidth,
                  constraints.maxWidth / template.aspectRatio,
                ),
                painter: _PhotoBoothPainter(
                  widget.renderer,
                  widget.document,
                  _images,
                ),
              ),
            ),
          );
        },
      ),
    );
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
