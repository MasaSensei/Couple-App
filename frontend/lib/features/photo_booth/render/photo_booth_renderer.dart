import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/photo_booth_document.dart';
import '../domain/photo_booth_template.dart';

/// Draws a Photo Booth print onto any canvas size. The on-screen preview and
/// the exported image both call [paint], so what the user sees is what is
/// saved. Runs entirely on the device; nothing here touches the network.
class PhotoBoothRenderer {
  const PhotoBoothRenderer({this.accent = const Color(0xFFE8899B)});

  /// The couple's theme accent, used for ornaments.
  final Color accent;

  void paint(
    Canvas canvas,
    Size size,
    PhotoBoothDocument document,
    List<ui.Image?> images,
  ) {
    final template = document.template;
    final scale = size.width / template.canvasSize.width;

    canvas.save();
    canvas.scale(scale);
    final bounds = Offset.zero & template.canvasSize;

    canvas.drawRect(bounds, Paint()..color = template.paper);
    _paintFrameBackground(canvas, template);

    final slotted = document.slotted;
    for (var i = 0; i < template.slots.length; i++) {
      _paintSlot(
        canvas,
        template,
        template.slots[i],
        i < images.length ? images[i] : null,
        i < slotted.length ? slotted[i].framing : PhotoFraming.centered,
      );
    }

    _paintFrameForeground(canvas, template);
    _paintCaption(canvas, document);
    canvas.restore();
  }

  /// The part of [image] that fills [slot] without distortion (centre crop).
  static Rect coverSourceRect(Size image, Size slot) =>
      framedSourceRect(image, slot, PhotoFraming.centered);

  /// The part of [image] shown in [slot] for [framing]: the cover crop shrunk
  /// by the zoom and centred on the focus, kept inside the photo so the slot
  /// is always filled.
  static Rect framedSourceRect(Size image, Size slot, PhotoFraming framing) {
    final crop = _cropSize(image, slot, framing.zoom);
    final focus = clampFocus(image, slot, framing);

    return Rect.fromCenter(
      center: Offset(focus.dx * image.width, focus.dy * image.height),
      width: crop.width,
      height: crop.height,
    );
  }

  /// [framing]'s focus limited to where the crop still lies inside [image].
  static Offset clampFocus(Size image, Size slot, PhotoFraming framing) {
    final crop = _cropSize(image, slot, framing.zoom);
    final halfX = crop.width / 2 / image.width;
    final halfY = crop.height / 2 / image.height;

    return Offset(
      framing.focus.dx.clamp(halfX, 1 - halfX),
      framing.focus.dy.clamp(halfY, 1 - halfY),
    );
  }

  /// Source size of the crop: the cover crop divided by [zoom].
  static Size _cropSize(Size image, Size slot, double zoom) {
    final cover = math.max(
      slot.width / image.width,
      slot.height / image.height,
    );
    final z = zoom.clamp(PhotoFraming.minZoom, PhotoFraming.maxZoom);

    return Size(
      math.min(image.width, slot.width / cover / z),
      math.min(image.height, slot.height / cover / z),
    );
  }

  void _paintSlot(
    Canvas canvas,
    PhotoBoothTemplate template,
    Rect slot,
    ui.Image? image,
    PhotoFraming framing,
  ) {
    final rrect = RRect.fromRectAndRadius(
      slot,
      Radius.circular(template.slotRadius),
    );

    canvas.save();
    canvas.clipRRect(rrect);

    if (image == null) {
      // Empty slot: a soft placeholder with a "+" so the layout is readable.
      canvas.drawRect(
        slot,
        Paint()
          ..color = Color.alphaBlend(
            accent.withValues(alpha: 0.18),
            template.paper,
          ),
      );
      final plus = Paint()
        ..color = template.ink.withValues(alpha: 0.35)
        ..strokeWidth = slot.shortestSide * 0.03
        ..strokeCap = StrokeCap.round;
      final c = slot.center;
      final arm = slot.shortestSide * 0.08;
      canvas.drawLine(c - Offset(arm, 0), c + Offset(arm, 0), plus);
      canvas.drawLine(c - Offset(0, arm), c + Offset(0, arm), plus);
    } else {
      final src = framedSourceRect(
        Size(image.width.toDouble(), image.height.toDouble()),
        slot.size,
        framing,
      );
      canvas.drawImageRect(
        image,
        src,
        slot,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    canvas.restore();
  }

  void _paintFrameBackground(Canvas canvas, PhotoBoothTemplate template) {
    final size = template.canvasSize;

    switch (template.frame) {
      case FrameStyle.film:
        // Sprocket holes down both edges.
        final hole = Paint()..color = const Color(0xFFEDE6DA);
        for (var y = 30.0; y < size.height - 40; y += 90) {
          for (final x in [40.0, size.width - 90]) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x, y, 50, 50),
                const Radius.circular(8),
              ),
              hole,
            );
          }
        }
      case FrameStyle.winter:
        final frost = Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, size.height),
            [const Color(0xFFE3EEF8), template.paper, const Color(0xFFE3EEF8)],
            [0, 0.5, 1],
          );
        canvas.drawRect(Offset.zero & size, frost);
      case FrameStyle.romantic:
        canvas.drawRect(
          (Offset.zero & size).deflate(40),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = accent.withValues(alpha: 0.55),
        );
      case FrameStyle.classic || FrameStyle.strip || FrameStyle.polaroid:
        break;
    }
  }

  void _paintFrameForeground(Canvas canvas, PhotoBoothTemplate template) {
    final size = template.canvasSize;

    switch (template.frame) {
      case FrameStyle.romantic:
        for (final corner in [
          const Offset(90, 90),
          Offset(size.width - 90, 90),
          Offset(90, size.height - 90),
          Offset(size.width - 90, size.height - 90),
        ]) {
          _heart(canvas, corner, 38, Paint()..color = accent);
        }
      case FrameStyle.winter:
        final flake = Paint()
          ..color = const Color(0xFF8DB3D6)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        final random = math.Random(42);
        for (var i = 0; i < 18; i++) {
          final edge = i.isEven;
          final x = edge
              ? random.nextDouble() * size.width
              : (i % 4 == 1 ? 50.0 : size.width - 50);
          final y = edge
              ? (i % 4 == 0 ? 60.0 : size.height - 60)
              : random.nextDouble() * size.height;
          _snowflake(
            canvas,
            Offset(x, y),
            18 + random.nextDouble() * 14,
            flake,
          );
        }
      case FrameStyle.strip:
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = template.ink.withValues(alpha: 0.12),
        );
      case FrameStyle.classic || FrameStyle.polaroid || FrameStyle.film:
        break;
    }
  }

  void _paintCaption(Canvas canvas, PhotoBoothDocument document) {
    final template = document.template;
    final area = template.captionArea;
    if (area == null) return;

    final lines = [
      if (document.caption.trim().isNotEmpty) document.caption.trim(),
      if (document.showDate) formatDate(document.date),
    ];
    if (lines.isEmpty) return;

    final painter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
      text: TextSpan(
        children: [
          for (final (i, line) in lines.indexed)
            TextSpan(
              text: i == 0 ? line : '\n$line',
              style: TextStyle(
                fontFamily: template.captionFont,
                fontSize: i == 0 && document.caption.trim().isNotEmpty
                    ? area.height * 0.32
                    : area.height * 0.2,
                color: i == 0
                    ? template.ink
                    : template.ink.withValues(alpha: 0.7),
                height: 1.25,
              ),
            ),
        ],
      ),
    )..layout(maxWidth: area.width);

    painter.paint(
      canvas,
      Offset(
        area.left + (area.width - painter.width) / 2,
        area.top + (area.height - painter.height) / 2,
      ),
    );
  }

  static String formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _heart(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r * 0.9)
      ..cubicTo(
        c.dx - r * 1.6,
        c.dy - r * 0.2,
        c.dx - r * 0.6,
        c.dy - r * 1.3,
        c.dx,
        c.dy - r * 0.4,
      )
      ..cubicTo(
        c.dx + r * 0.6,
        c.dy - r * 1.3,
        c.dx + r * 1.6,
        c.dy - r * 0.2,
        c.dx,
        c.dy + r * 0.9,
      );
    canvas.drawPath(path, paint);
  }

  void _snowflake(Canvas canvas, Offset c, double r, Paint paint) {
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * r, paint);
    }
  }
}
