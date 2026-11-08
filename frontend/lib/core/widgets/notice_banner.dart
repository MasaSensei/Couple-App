import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_tokens.dart';

/// Inline message in a tone (form errors, plan notices, protection hints).
/// Announced to screen readers when it appears.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    required this.message,
    super.key,
    this.tone = StatusTone.info,
    this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final StatusTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  IconData get _icon =>
      icon ??
      switch (tone) {
        StatusTone.success => Icons.check_circle_outline_rounded,
        StatusTone.warning => Icons.warning_amber_rounded,
        StatusTone.error => Icons.error_outline_rounded,
        _ => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = t.onToneContainer(tone);

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.smd),
        decoration: BoxDecoration(
          color: t.toneContainer(tone),
          borderRadius: BorderRadius.circular(t.cardRadius * 0.7),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, color: fg, size: 20),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: t.body.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    message,
                    style: t.body.copyWith(color: fg, fontSize: 14),
                  ),
                  if (actionLabel != null && onAction != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: fg,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(actionLabel!),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
