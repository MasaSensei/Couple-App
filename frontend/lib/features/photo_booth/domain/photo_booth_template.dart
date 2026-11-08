import 'package:flutter/material.dart';

/// Visual family of a template's frame (drawn by `PhotoBoothRenderer`).
enum FrameStyle { classic, strip, polaroid, film, romantic, winter }

/// A Photo Booth layout, as data. Coordinates are in the template's own
/// canvas units ([canvasSize]); the renderer scales them to any output size,
/// so preview and export always share one layout.
///
/// Keys are shared with the backend catalog, which only decides availability.
@immutable
class PhotoBoothTemplate {
  const PhotoBoothTemplate({
    required this.key,
    required this.name,
    required this.canvasSize,
    required this.slots,
    required this.frame,
    required this.paper,
    required this.ink,
    this.captionArea,
    this.slotRadius = 0,
    this.captionFont,
  });

  final String key;
  final String name;
  final Size canvasSize;

  /// Photo positions in canvas units, in fill order.
  final List<Rect> slots;

  final FrameStyle frame;

  /// Background ("paper") and text colour of the print.
  final Color paper;
  final Color ink;

  /// Where caption and date go; null = no text on this layout.
  final Rect? captionArea;
  final double slotRadius;

  /// A bundled font family for the caption (null = default).
  final String? captionFont;

  int get photoCount => slots.length;

  double get aspectRatio => canvasSize.width / canvasSize.height;
}
