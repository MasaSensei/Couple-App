import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_tokens.dart';
import 'ornament.dart';

/// The app's card: radius, border and elevation from the theme, a gentle
/// press scale (off with reduce motion), and an optional theme ornament.
class JournalCard extends StatefulWidget {
  const JournalCard({
    required this.child,
    super.key,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.ornament = false,
    this.ornamentSeed = 0,
    this.color,
    this.elevation,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Show the theme's scrapbook touch (memory/date cards only).
  final bool ornament;
  final int ornamentSeed;

  /// Override the surface colour (e.g. a tinted highlight card).
  final Color? color;

  /// 0–3; defaults to the theme's card elevation.
  final int? elevation;

  /// Read by screen readers instead of every child text when set.
  final String? semanticLabel;

  @override
  State<JournalCard> createState() => _JournalCardState();
}

class _JournalCardState extends State<JournalCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final motion = context.motion;
    final radius = BorderRadius.circular(t.cardRadius);
    final level = widget.elevation ?? t.cardElevation.round();

    Widget card = AnimatedScale(
      scale: _pressed ? motion.pressScale : 1,
      duration: motion.fast,
      curve: AppMotion.standard,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.color ?? t.surface,
          borderRadius: radius,
          border: t.cardBorder || t.isDark ? Border.all(color: t.border) : null,
          boxShadow: t.elevation(level),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: widget.onTap == null ? null : _setPressed,
            borderRadius: radius,
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );

    if (widget.ornament) {
      card = Ornamented(seed: widget.ornamentSeed, child: card);
    }

    if (widget.semanticLabel != null) {
      card = Semantics(
        label: widget.semanticLabel,
        button: widget.onTap != null,
        excludeSemantics: true,
        child: card,
      );
    }

    return card;
  }
}
