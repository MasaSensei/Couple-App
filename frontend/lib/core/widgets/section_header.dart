import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_tokens.dart';

/// "NEXT DATE · See all": an overline (or title) with an optional action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.large = false,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Display-face title (screen sections) instead of the small overline.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  large ? title : title.toUpperCase(),
                  style: large ? t.title : t.overline,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subtitle!, style: t.caption),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
