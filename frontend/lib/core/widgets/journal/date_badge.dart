import 'package:flutter/material.dart';

import '../../format/app_formatters.dart';
import '../../theme/app_theme_tokens.dart';

enum DateBadgeEmphasis { strong, soft, muted }

/// Ticket stub: big day number over a short month, e.g. "14 / NOV".
class DateBadge extends StatelessWidget {
  const DateBadge({
    required this.date,
    super.key,
    this.emphasis = DateBadgeEmphasis.strong,
    this.width = 56,
  });

  final DateTime date;
  final DateBadgeEmphasis emphasis;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final local = date.toLocal();
    final (bg, fg) = switch (emphasis) {
      DateBadgeEmphasis.strong => (t.primary, t.onPrimary),
      DateBadgeEmphasis.soft => (t.secondary, t.textPrimary),
      DateBadgeEmphasis.muted => (t.surfaceMuted, t.textSecondary),
    };

    return Semantics(
      label: AppFormatters.dayMonthYear(local),
      excludeSemantics: true,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(t.cardRadius * 0.6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${local.day}',
              style: t.title.copyWith(color: fg, fontSize: 24, height: 1),
            ),
            const SizedBox(height: 2),
            Text(
              AppFormatters.monthShort(local).toUpperCase(),
              style: t.overline.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
