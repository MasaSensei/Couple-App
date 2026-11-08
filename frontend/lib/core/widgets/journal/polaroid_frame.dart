import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme_tokens.dart';
import 'ornament.dart';

/// A photo print: paper border, slightly thicker at the bottom for a
/// handwritten caption, and a small deterministic tilt (from [seed], so it is
/// stable across rebuilds and never animates).
///
/// [photo] is any widget (e.g. the decrypted `PrivateMemoryPhoto`); this frame
/// never loads images itself.
class PolaroidFrame extends StatelessWidget {
  const PolaroidFrame({
    required this.photo,
    super.key,
    this.caption,
    this.trailing,
    this.seed = 0,
    this.tilt = true,
    this.aspectRatio = 1,
    this.ornament = true,
  });

  final Widget photo;
  final String? caption;

  /// Small meta on the right of the caption line (e.g. "6 NOV").
  final String? trailing;
  final int seed;
  final bool tilt;
  final double aspectRatio;
  final bool ornament;

  /// -1.6°..+1.6° in 0.8° steps, chosen by [seed].
  static double tiltFor(int seed) => ((seed % 5) - 2) * 0.014;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasCaption = caption != null || trailing != null;

    Widget frame = DecoratedBox(
      decoration: BoxDecoration(
        color: t.paper,
        borderRadius: BorderRadius.circular(3),
        boxShadow: t.elevation(2),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
          hasCaption ? AppSpacing.xs : AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(t.photoRadius),
                child: photo,
              ),
            ),
            if (hasCaption)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        caption ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.handwriting.copyWith(
                          color: t.onPaper,
                          fontSize: (t.handwriting.fontSize ?? 20) * 0.9,
                        ),
                      ),
                    ),
                    if (trailing != null)
                      Text(
                        trailing!,
                        style: t.overline.copyWith(
                          color: t.onPaper.withValues(alpha: 0.72),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    if (ornament) frame = Ornamented(seed: seed, child: frame);

    if (!tilt) return frame;
    return Transform.rotate(angle: tiltFor(seed), child: frame);
  }
}
