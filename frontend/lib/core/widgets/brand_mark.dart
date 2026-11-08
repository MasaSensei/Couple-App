import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../theme/app_theme_tokens.dart';

/// The wordmark: "our little space" in the brand serif italic with a small
/// heart as its full stop. Always the brand face, whatever the theme, so the
/// product stays recognisable.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: 'Our Little Space',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'our little space',
            style: TextStyle(
              fontFamily: AppTextStyles.displayFamily,
              fontStyle: FontStyle.italic,
              fontVariations: const [FontVariation('wght', 500)],
              fontSize: size,
              height: 1.1,
              color: t.textPrimary,
            ),
          ),
          SizedBox(width: size * 0.15),
          Icon(Icons.favorite_rounded, size: size * 0.55, color: t.primary),
        ],
      ),
    );
  }
}
