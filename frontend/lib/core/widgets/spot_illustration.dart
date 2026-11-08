import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';

enum SpotKind { camera, calendar, envelope, cloudOff, heart, palette, lock }

/// Single-line spot illustrations for empty and error states, drawn in the
/// theme's soft text colour with one primary accent. No raster assets.
class SpotIllustration extends StatelessWidget {
  const SpotIllustration({required this.kind, super.key, this.size = 96});

  final SpotKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _SpotPainter(
            kind: kind,
            line: t.textSecondary,
            accent: t.primary,
            fill: t.secondary.withValues(alpha: t.isDark ? 0.5 : 0.7),
          ),
        ),
      ),
    );
  }
}

class _SpotPainter extends CustomPainter {
  _SpotPainter({
    required this.kind,
    required this.line,
    required this.accent,
    required this.fill,
  });

  final SpotKind kind;
  final Color line;
  final Color accent;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 96;
    canvas.scale(s);
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final accentStroke = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final soft = Paint()..color = fill;

    // A soft blob behind every illustration.
    canvas.drawOval(const Rect.fromLTWH(14, 22, 70, 56), soft);

    switch (kind) {
      case SpotKind.camera:
        canvas.drawRRect(
          RRect.fromLTRBR(20, 34, 76, 74, const Radius.circular(8)),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(36, 34)
            ..lineTo(40, 27)
            ..lineTo(56, 27)
            ..lineTo(60, 34),
          stroke,
        );
        canvas.drawCircle(const Offset(48, 54), 12, stroke);
        canvas.drawCircle(const Offset(48, 54), 5, accentStroke);
        _heart(canvas, const Offset(74, 22), 5, accentStroke);
      case SpotKind.calendar:
        canvas.drawRRect(
          RRect.fromLTRBR(22, 30, 74, 76, const Radius.circular(8)),
          stroke,
        );
        canvas.drawLine(const Offset(22, 42), const Offset(74, 42), stroke);
        canvas.drawLine(const Offset(34, 24), const Offset(34, 34), stroke);
        canvas.drawLine(const Offset(62, 24), const Offset(62, 34), stroke);
        for (var r = 0; r < 2; r++) {
          for (var c = 0; c < 4; c++) {
            canvas.drawCircle(
              Offset(32 + c * 11, 52 + r * 12),
              1.6,
              Paint()..color = line,
            );
          }
        }
        _heart(canvas, const Offset(65, 64), 5, accentStroke);
      case SpotKind.envelope:
        canvas.drawRRect(
          RRect.fromLTRBR(18, 34, 78, 72, const Radius.circular(6)),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(18, 36)
            ..lineTo(48, 56)
            ..lineTo(78, 36),
          stroke,
        );
        _heart(canvas, const Offset(48, 24), 7, accentStroke);
      case SpotKind.cloudOff:
        canvas.drawPath(
          Path()
            ..moveTo(28, 66)
            ..cubicTo(16, 66, 16, 48, 28, 48)
            ..cubicTo(28, 34, 50, 30, 54, 42)
            ..cubicTo(66, 36, 78, 46, 72, 56)
            ..cubicTo(80, 58, 78, 66, 70, 66)
            ..close(),
          stroke,
        );
        canvas.drawLine(
          const Offset(26, 30),
          const Offset(72, 76),
          accentStroke,
        );
      case SpotKind.heart:
        _heart(canvas, const Offset(48, 50), 20, stroke);
        _heart(canvas, const Offset(70, 28), 6, accentStroke);
      case SpotKind.palette:
        canvas.drawPath(
          Path()
            ..moveTo(48, 26)
            ..cubicTo(26, 26, 18, 46, 22, 58)
            ..cubicTo(26, 72, 44, 76, 50, 72)
            ..cubicTo(56, 68, 50, 62, 56, 60)
            ..cubicTo(64, 58, 76, 62, 76, 48)
            ..cubicTo(76, 34, 64, 26, 48, 26),
          stroke,
        );
        for (final p in const [
          Offset(36, 44),
          Offset(48, 38),
          Offset(62, 44),
        ]) {
          canvas.drawCircle(p, 4, p.dx == 48 ? accentStroke : stroke);
        }
      case SpotKind.lock:
        canvas.drawRRect(
          RRect.fromLTRBR(28, 46, 68, 76, const Radius.circular(6)),
          stroke,
        );
        canvas.drawArc(
          const Rect.fromLTWH(36, 28, 24, 30),
          math.pi,
          math.pi,
          false,
          stroke,
        );
        canvas.drawLine(const Offset(36, 43), const Offset(36, 46), stroke);
        canvas.drawLine(const Offset(60, 43), const Offset(60, 46), stroke);
        _heart(canvas, const Offset(48, 61), 5, accentStroke);
    }
  }

  void _heart(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r * 0.9)
      ..cubicTo(
        c.dx - r * 1.6,
        c.dy - r * 0.2,
        c.dx - r * 0.7,
        c.dy - r * 1.3,
        c.dx,
        c.dy - r * 0.45,
      )
      ..cubicTo(
        c.dx + r * 0.7,
        c.dy - r * 1.3,
        c.dx + r * 1.6,
        c.dy - r * 0.2,
        c.dx,
        c.dy + r * 0.9,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SpotPainter old) =>
      old.kind != kind ||
      old.line != line ||
      old.accent != accent ||
      old.fill != fill;
}
