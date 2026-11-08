import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme_tokens.dart';
import '../../theme/theme_definition.dart';

/// Draws the active theme's scrapbook touch (washi tape, stamp, filigree…)
/// on the *edge* of [child]. Purely decorative: ignores pointers, hidden from
/// screen readers, painted once (no animation) and skipped when the couple
/// switched decorations off.
class Ornamented extends StatelessWidget {
  const Ornamented({required this.child, super.key, this.kind, this.seed = 0});

  final Widget child;

  /// Override; defaults to the theme's ornament.
  final OrnamentKind? kind;

  /// Varies tape angle per item so a list does not look stamped out.
  final int seed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final k = kind ?? t.ornament;
    if (!t.ornamentsEnabled || k == OrnamentKind.none) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: OrnamentPainter(
                  kind: k,
                  primary: t.primary,
                  // Dark secondaries are too murky for tape/petals; lift them.
                  secondary: t.isDark
                      ? Color.lerp(t.secondary, t.primary, 0.45)!
                      : t.secondary,
                  accent: t.accent,
                  ink: t.textPrimary,
                  seed: seed,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class OrnamentPainter extends CustomPainter {
  OrnamentPainter({
    required this.kind,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.ink,
    this.seed = 0,
  });

  final OrnamentKind kind;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color ink;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final tilt = ((seed * 37) % 7 - 3) * math.pi / 180; // -3°..+3°

    switch (kind) {
      case OrnamentKind.none:
        return;
      case OrnamentKind.washiTape:
        _tape(canvas, Offset(size.width / 2, 1), tilt - 0.06, secondary);
      case OrnamentKind.petal:
        _petal(canvas, Offset(size.width - 10, 2), 0.5 + tilt);
        _petal(canvas, Offset(size.width - 22, -3), -0.3 + tilt, scale: 0.7);
      case OrnamentKind.snowflakeStamp:
        _snowflake(canvas, Offset(size.width - 12, 4));
      case OrnamentKind.star:
        _star(canvas, Offset(size.width - 10, 2), 7, accent);
        _star(
          canvas,
          Offset(size.width - 24, 10),
          3.5,
          accent.withValues(alpha: 0.7),
        );
      case OrnamentKind.goldStar:
        // Gold is the theme's primary (Starry Night), not its blue accent.
        final glow = Paint()
          ..color = primary.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(Offset(size.width - 12, 4), 9, glow);
        _star(canvas, Offset(size.width - 12, 4), 9, primary);
      case OrnamentKind.filmSprockets:
        _sprockets(canvas, size);
      case OrnamentKind.filigree:
        _filigree(canvas, size);
      case OrnamentKind.pressedFlower:
        _flower(canvas, const Offset(10, 4));
      case OrnamentKind.kraftTag:
        _kraftTag(canvas, const Offset(14, -6), tilt);
    }
  }

  void _tape(Canvas canvas, Offset center, double angle, Color color) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final rect = Rect.fromCenter(center: Offset.zero, width: 54, height: 16);
    final paint = Paint()..color = color.withValues(alpha: 0.85);
    // Torn ends: a zig-zag on both short sides.
    final path = Path()..moveTo(rect.left, rect.top);
    path.lineTo(rect.right, rect.top);
    for (var i = 0; i <= 4; i++) {
      path.lineTo(
        rect.right + (i.isOdd ? -2 : 0),
        rect.top + i * rect.height / 4,
      );
    }
    path.lineTo(rect.left, rect.bottom);
    for (var i = 4; i >= 0; i--) {
      path.lineTo(
        rect.left + (i.isOdd ? 2 : 0),
        rect.top + i * rect.height / 4,
      );
    }
    path.close();
    canvas.drawShadow(path, ink.withValues(alpha: 0.3), 1, false);
    canvas.drawPath(path, paint);
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 2;
    for (var x = rect.left + 6; x < rect.right - 4; x += 8) {
      canvas.drawLine(
        Offset(x, rect.top + 2),
        Offset(x + 4, rect.bottom - 2),
        stripe,
      );
    }
    canvas.restore();
  }

  void _petal(Canvas canvas, Offset at, double angle, {double scale = 1}) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.scale(scale);
    final path = Path()
      ..moveTo(0, -9)
      ..quadraticBezierTo(8, -2, 0, 9)
      ..quadraticBezierTo(-8, -2, 0, -9)
      ..close();
    canvas.drawPath(path, Paint()..color = accent.withValues(alpha: 0.85));
    canvas.drawLine(
      const Offset(0, -6),
      const Offset(0, 6),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  void _snowflake(Canvas canvas, Offset c) {
    final ring = Paint()
      ..color = primary.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(
      c,
      12,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    // Dashed stamp edge.
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 12),
        a,
        math.pi / 14,
        false,
        ring,
      );
    }
    final arm = Paint()
      ..color = primary
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c, c + d * 7, arm);
      final mid = c + d * 4.5;
      final n = Offset(-d.dy, d.dx) * 2;
      canvas.drawLine(mid, mid + d * 2 + n, arm);
      canvas.drawLine(mid, mid + d * 2 - n, arm);
    }
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a), math.sin(a)) * radius;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _sprockets(Canvas canvas, Size size) {
    final paint = Paint()..color = ink.withValues(alpha: 0.32);
    const w = 7.0, h = 4.0, gap = 7.0;
    for (var x = 8.0; x + w < size.width - 6; x += w + gap) {
      for (final y in [3.0, size.height - 3 - h]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, h),
            const Radius.circular(1.2),
          ),
          paint,
        );
      }
    }
  }

  void _filigree(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    const inset = 5.0, len = 16.0;
    final corners = [
      (const Offset(inset, inset), 1.0, 1.0),
      (Offset(size.width - inset, inset), -1.0, 1.0),
      (Offset(inset, size.height - inset), 1.0, -1.0),
      (Offset(size.width - inset, size.height - inset), -1.0, -1.0),
    ];
    for (final (o, sx, sy) in corners) {
      final path = Path()
        ..moveTo(o.dx, o.dy + sy * len)
        ..lineTo(o.dx, o.dy)
        ..lineTo(o.dx + sx * len, o.dy);
      canvas.drawPath(path, paint);
      canvas.drawCircle(
        o + Offset(sx * 4, sy * 4),
        1.6,
        Paint()..color = accent,
      );
      canvas.drawArc(
        Rect.fromCircle(center: o + Offset(sx * 7, sy * 7), radius: 3),
        0,
        math.pi * 1.5,
        false,
        paint,
      );
    }
  }

  void _flower(Canvas canvas, Offset c) {
    final petal = Paint()..color = secondary;
    final edge = Paint()
      ..color = accent.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5 - math.pi / 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * 6;
      canvas.drawCircle(p, 5, petal);
      canvas.drawCircle(p, 5, edge);
    }
    canvas.drawCircle(c, 3.2, Paint()..color = accent);
    // Stem.
    canvas.drawLine(
      c + const Offset(3, 9),
      c + const Offset(12, 20),
      Paint()
        ..color = primary.withValues(alpha: 0.6)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _kraftTag(Canvas canvas, Offset at, double angle) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle - 0.05);
    const kraft = Color(0xFFC8A27A);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(34, 0)
      ..lineTo(42, 8)
      ..lineTo(34, 16)
      ..lineTo(0, 16)
      ..close();
    canvas.drawShadow(path, ink.withValues(alpha: 0.3), 1.5, false);
    canvas.drawPath(path, Paint()..color = kraft);
    canvas.drawCircle(
      const Offset(34, 8),
      2,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
    canvas.drawLine(
      const Offset(5, 8),
      const Offset(26, 8),
      Paint()
        ..color = const Color(0xFF6F4E37).withValues(alpha: 0.45)
        ..strokeWidth = 1.2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant OrnamentPainter old) =>
      old.kind != kind ||
      old.primary != primary ||
      old.secondary != secondary ||
      old.accent != accent ||
      old.ink != ink ||
      old.seed != seed;
}
