import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';

/// Status as colour *and* icon *and* words (never colour alone).
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.tone,
    super.key,
    this.icon,
    this.dense = false,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = t.onToneContainer(tone);

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 10,
          vertical: dense ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: t.toneContainer(tone),
          borderRadius: BorderRadius.circular(t.chipRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: dense ? 13 : 15, color: fg),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.label.copyWith(
                  color: fg,
                  fontSize: dense ? 11.5 : 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
