import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/app_theme_tokens.dart';
import 'package:frontend/core/theme/theme_customization.dart';
import 'package:frontend/core/theme/theme_decorations.dart';
import 'package:frontend/core/theme/theme_definition.dart';

/// Renders [definition] + [customization] in its own [Theme] subtree, so a
/// preview never changes the active app theme.
class ThemeScope extends StatelessWidget {
  const ThemeScope({
    super.key,
    required this.definition,
    required this.child,
    this.customization = ThemeCustomization.defaults,
    this.animate = false,
  });

  final ThemeDefinition definition;
  final ThemeCustomization customization;
  final Widget child;

  /// Small gallery cards stay still; the detail preview may animate.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final data = AppTheme.build(
      definition,
      Theme.of(context).brightness,
      customization: customization,
    );
    final tokens = data.extension<AppThemeTokens>()!;

    return Theme(
      data: animate
          ? data
          : data.copyWith(
              extensions: [tokens.copyWith(animationsEnabled: false)],
            ),
      child: child,
    );
  }
}

/// A miniature Couple Space + memory card, drawn with the surrounding theme.
class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scale = compact ? 0.62 : 1.0;

    return Material(
      color: t.background,
      child: ThemedBackground(
        child: Padding(
          padding: EdgeInsets.all(16 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Our Little Space',
                style: t.title.copyWith(fontSize: t.title.fontSize! * scale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4 * scale),
              Text(
                'Hello, love ♡',
                style: t.subtitle.copyWith(
                  fontSize: t.subtitle.fontSize! * scale,
                ),
                maxLines: 1,
              ),
              SizedBox(height: 12 * scale),
              _MemoryPreviewCard(scale: scale),
              const Spacer(),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * scale,
                    vertical: 8 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: t.primary,
                    borderRadius: BorderRadius.circular(t.buttonRadius * scale),
                  ),
                  child: Text(
                    'Add memory',
                    style: t.button.copyWith(
                      fontSize: t.button.fontSize! * scale,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryPreviewCard extends StatelessWidget {
  const _MemoryPreviewCard({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final photo = Container(
      height: 64 * scale,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [t.secondary, t.accent]),
        borderRadius: BorderRadius.circular(
          t.memoryStyle == MemoryStyle.minimal ? 0 : 10 * scale,
        ),
      ),
      child: Icon(
        Icons.favorite_rounded,
        color: t.surface.withValues(alpha: 0.85),
        size: 24 * scale,
      ),
    );

    return Container(
      padding: EdgeInsets.all(
        (t.memoryStyle == MemoryStyle.polaroid ? 8 : 10) * scale,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(
          (t.memoryStyle == MemoryStyle.polaroid ? 4 : t.cardRadius) * scale,
        ),
        border: t.cardBorder ? Border.all(color: t.border) : null,
        boxShadow: t.cardElevation > 0 || t.memoryStyle == MemoryStyle.polaroid
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6 * scale,
                  offset: Offset(0, 2 * scale),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          photo,
          SizedBox(height: 6 * scale),
          Text(
            'Our first date',
            style: t.body.copyWith(
              fontSize: t.body.fontSize! * scale,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
