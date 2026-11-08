import 'package:flutter/material.dart';

import '../../theme/app_theme_tokens.dart';

/// Two overlapping initials. The second circle is a dashed "waiting" ring
/// while the partner has not joined yet.
class CoupleAvatars extends StatelessWidget {
  const CoupleAvatars({
    required this.firstName,
    super.key,
    this.secondName,
    this.size = 40,
  });

  final String firstName;
  final String? secondName;
  final double size;

  static String initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ring = Border.all(color: t.background, width: 2.5);

    Widget circle(String text, Color bg, Color fg) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: ring,
      ),
      child: Text(
        text,
        style: t.label.copyWith(
          color: fg,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    final label = secondName == null
        ? '$firstName, waiting for a partner'
        : '$firstName and $secondName';

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: size * 1.7,
        height: size,
        child: Stack(
          children: [
            circle(initial(firstName), t.secondary, t.textPrimary),
            Positioned(
              left: size * 0.7,
              child: secondName == null
                  ? Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.surfaceMuted,
                        border: Border.all(color: t.border, width: 1.5),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: size * 0.5,
                        color: t.textSecondary,
                      ),
                    )
                  : circle(initial(secondName!), t.primary, t.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
