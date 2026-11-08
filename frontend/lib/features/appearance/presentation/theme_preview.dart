import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/theme_customization.dart';
import 'package:frontend/core/widgets/app_widgets.dart';
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

/// A miniature Couple Space drawn with the real components and the
/// surrounding theme (so what you see is what the theme does). Laid out at a
/// fixed phone-like size and scaled to fit, so it never overflows a card.
class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key, this.compact = false});

  final bool compact;

  static final _sample = DateTime(2026, 11, 14, 19);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final page = SizedBox(
      width: 240,
      height: compact ? 340 : 380,
      child: Material(
        color: t.background,
        child: ThemedBackground(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CoupleAvatars(
                      firstName: 'A',
                      secondName: 'B',
                      size: 30,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good evening',
                            style: t.handwriting.copyWith(fontSize: 14),
                            maxLines: 1,
                          ),
                          Text(
                            'Our little space',
                            style: t.title.copyWith(fontSize: 18),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                JournalCard(
                  ornament: true,
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      DateBadge(date: _sample, width: 44),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dinner date',
                              style: t.heading.copyWith(fontSize: 14),
                              maxLines: 1,
                            ),
                            const SizedBox(height: 4),
                            const StatusChip(
                              label: 'Planned',
                              tone: StatusTone.brand,
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (seed, a, b) in [
                      (1, t.secondary, t.primary),
                      (2, t.accent, t.secondary),
                    ]) ...[
                      SizedBox(
                        width: 84,
                        child: PolaroidFrame(
                          seed: seed,
                          ornament: seed == 1,
                          caption: seed == 1 ? 'first trip' : 'us',
                          photo: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [a, b],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (seed == 1) const SizedBox(width: 16),
                    ],
                  ],
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: t.primary,
                      borderRadius: BorderRadius.circular(t.buttonRadius),
                    ),
                    child: Text(
                      'New memory',
                      style: t.button.copyWith(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        child: MediaQuery.withNoTextScaling(child: page),
      ),
    );
  }
}
