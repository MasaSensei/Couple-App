import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme_tokens.dart';
import 'theme_definition.dart';

/// Paints the active theme's ornaments behind [child]. Decorative only:
/// ignores pointers, is hidden from screen readers, and is drawn at low
/// opacity so text above it stays readable. Animates only when the theme,
/// the couple's toggle, the user's preference *and* the platform
/// "reduce motion" setting all allow it.
class ThemedBackground extends StatefulWidget {
  const ThemedBackground({super.key, required this.child, this.tokens});

  final Widget child;

  /// Override for previews of a theme that is not the active one.
  final AppThemeTokens? tokens;

  @override
  State<ThemedBackground> createState() => _ThemedBackgroundState();
}

class _ThemedBackgroundState extends State<ThemedBackground>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant ThemedBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final tokens = widget.tokens ?? context.tokens;
    final animate =
        tokens.decorationsEnabled &&
        tokens.animationsEnabled &&
        !MediaQuery.of(context).disableAnimations;

    if (!animate) {
      _controller?.dispose();
      _controller = null;
      return;
    }

    final period = tokens.animation.period;
    if (_controller?.duration != period) {
      _controller?.dispose();
      _controller = AnimationController(vsync: this, duration: period)
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens ?? context.tokens;

    if (!tokens.decorationsEnabled) return widget.child;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: ThemeDecorationPainter(
                    decoration: tokens.decoration,
                    animation: tokens.animation.kind,
                    color: tokens.accent,
                    secondaryColor: tokens.primary,
                    progress: _controller,
                  ),
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Deterministic ornaments per [DecorationKind]: the same layout on every
/// frame and device (seeded), moved only by [progress] when animating.
class ThemeDecorationPainter extends CustomPainter {
  ThemeDecorationPainter({
    required this.decoration,
    required this.animation,
    required this.color,
    required this.secondaryColor,
    this.progress,
  }) : super(repaint: progress);

  final ThemeDecoration decoration;
  final AnimationKind animation;
  final Color color;
  final Color secondaryColor;
  final Animation<double>? progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || decoration.kind == DecorationKind.none) return;

    final t = progress?.value ?? 0;
    final random = math.Random(decoration.kind.index * 7919);
    final count = (24 * decoration.density).round();

    switch (decoration.kind) {
      case DecorationKind.none:
        return;
      case DecorationKind.filmGrain:
        _filmGrain(canvas, size, random);
        return;
      case DecorationKind.ornaments:
        _ornaments(canvas, size);
      case DecorationKind.constellations:
        _moon(canvas, size);
      default:
        break;
    }

    final constellation = <Offset>[];

    for (var i = 0; i < count; i++) {
      final baseX = random.nextDouble();
      final baseY = random.nextDouble();
      final phase = random.nextDouble();
      final scale = 0.6 + random.nextDouble() * 0.8;
      final rotation = random.nextDouble() * math.pi * 2;

      var dx = baseX;
      var dy = baseY;
      var alpha = 1.0;

      switch (animation) {
        case AnimationKind.fall:
          dy = (baseY + t) % 1.0;
          dx = baseX + math.sin((t + phase) * math.pi * 2) * 0.02;
        case AnimationKind.drift:
          dx = baseX + math.sin((t + phase) * math.pi * 2) * 0.015;
          dy = baseY + math.cos((t + phase) * math.pi * 2) * 0.01;
        case AnimationKind.twinkle:
          alpha =
              0.35 + 0.65 * (0.5 + 0.5 * math.sin((t + phase) * math.pi * 2));
        case AnimationKind.none:
          break;
      }

      final center = Offset(dx * size.width, dy * size.height);
      final paint = Paint()
        ..color = color.withValues(alpha: decoration.opacity * alpha)
        ..isAntiAlias = true;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(
        rotation + (animation == AnimationKind.fall ? t * math.pi : 0),
      );
      canvas.scale(scale);

      switch (decoration.kind) {
        case DecorationKind.petals:
          _petal(canvas, paint);
        case DecorationKind.snowflakes:
          _snowflake(canvas, paint);
        case DecorationKind.stars:
          _glowStar(
            canvas,
            paint,
            color.withValues(alpha: decoration.opacity * alpha),
          );
        case DecorationKind.leaves:
          _leaf(
            canvas,
            paint..color = secondaryColor.withValues(alpha: decoration.opacity),
          );
        case DecorationKind.coffee:
          i.isEven ? _bean(canvas, paint) : _steam(canvas, paint);
        case DecorationKind.ornaments:
          _sparkle(canvas, paint);
        case DecorationKind.constellations:
          _glowStar(
            canvas,
            paint,
            color.withValues(alpha: decoration.opacity * alpha),
          );
          if (i % 4 == 0) constellation.add(center);
        default:
          break;
      }

      canvas.restore();
    }

    if (constellation.length > 1) {
      final line = Paint()
        ..color = color.withValues(alpha: decoration.opacity * 0.35)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < constellation.length - 1; i++) {
        if ((constellation[i] - constellation[i + 1]).distance <
            size.shortestSide * 0.45) {
          canvas.drawLine(constellation[i], constellation[i + 1], line);
        }
      }
    }
  }

  void _petal(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(0, -9)
      ..quadraticBezierTo(8, -3, 0, 9)
      ..quadraticBezierTo(-8, -3, 0, -9);
    canvas.drawPath(path, paint);
  }

  void _snowflake(Canvas canvas, Paint paint) {
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var arm = 0; arm < 6; arm++) {
      canvas.drawLine(Offset.zero, const Offset(0, -9), paint);
      canvas.drawLine(const Offset(0, -6), const Offset(3, -8.5), paint);
      canvas.drawLine(const Offset(0, -6), const Offset(-3, -8.5), paint);
      canvas.rotate(math.pi / 3);
    }
  }

  void _glowStar(Canvas canvas, Paint paint, Color core) {
    canvas.drawCircle(
      Offset.zero,
      6,
      Paint()
        ..shader = RadialGradient(colors: [core, core.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: Offset.zero, radius: 6)),
    );
    canvas.drawCircle(Offset.zero, 1.3, paint);
  }

  void _leaf(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(0, -11)
      ..cubicTo(8, -6, 7, 6, 0, 11)
      ..cubicTo(-7, 6, -8, -6, 0, -11);
    canvas.drawPath(path, paint);
    canvas.drawLine(
      const Offset(0, -9),
      const Offset(0, 9),
      Paint()
        ..color = paint.color.withValues(alpha: paint.color.a * 0.6)
        ..strokeWidth = 0.8,
    );
  }

  void _bean(Canvas canvas, Paint paint) {
    canvas.drawOval(const Rect.fromLTWH(-5, -7, 10, 14), paint);
    canvas.drawLine(
      const Offset(0, -6),
      const Offset(0, 6),
      Paint()
        ..color = paint.color.withValues(alpha: paint.color.a * 0.5)
        ..strokeWidth = 1,
    );
  }

  void _steam(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(0, 10)
      ..cubicTo(-6, 4, 6, -2, 0, -10);
    canvas.drawPath(
      path,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }

  void _sparkle(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(0, -6)
      ..lineTo(1.2, -1.2)
      ..lineTo(6, 0)
      ..lineTo(1.2, 1.2)
      ..lineTo(0, 6)
      ..lineTo(-1.2, 1.2)
      ..lineTo(-6, 0)
      ..lineTo(-1.2, -1.2)
      ..close();
    canvas.drawPath(path, paint);
  }

  /// Gold filigree in the four corners.
  void _ornaments(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: decoration.opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final r = size.shortestSide * 0.16;

    for (final (corner, sx, sy) in [
      (Offset.zero, 1.0, 1.0),
      (Offset(size.width, 0), -1.0, 1.0),
      (Offset(0, size.height), 1.0, -1.0),
      (Offset(size.width, size.height), -1.0, -1.0),
    ]) {
      canvas.save();
      canvas.translate(corner.dx, corner.dy);
      canvas.scale(sx, sy);
      final path = Path()
        ..moveTo(8, r)
        ..quadraticBezierTo(8, 8, r, 8)
        ..moveTo(16, r * 0.7)
        ..quadraticBezierTo(16, 16, r * 0.7, 16)
        ..addOval(
          Rect.fromCircle(center: Offset(r * 0.35, r * 0.35), radius: 3),
        );
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  void _moon(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.82, size.height * 0.1);
    final radius = size.shortestSide * 0.06;
    final paint = Paint()
      ..color = color.withValues(alpha: decoration.opacity * 0.8);
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      Path()..addOval(
        Rect.fromCircle(
          center: center + Offset(radius * 0.45, -radius * 0.2),
          radius: radius,
        ),
      ),
    );
    canvas.drawPath(moon, paint);
  }

  void _filmGrain(Canvas canvas, Size size, math.Random random) {
    final grain = Paint()
      ..color = secondaryColor.withValues(alpha: decoration.opacity);
    final dots = (size.width * size.height / 900 * decoration.density)
        .clamp(0, 2500)
        .round();
    for (var i = 0; i < dots; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.6,
        grain,
      );
    }

    // Vignette: darker edges like an old print.
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [
            Colors.transparent,
            secondaryColor.withValues(alpha: decoration.opacity * 1.6),
          ],
          stops: const [0.72, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant ThemeDecorationPainter old) =>
      old.decoration != decoration ||
      old.color != color ||
      old.secondaryColor != secondaryColor ||
      old.animation != animation;
}
