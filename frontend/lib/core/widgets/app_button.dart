import 'package:flutter/material.dart';

import '../theme/app_theme_tokens.dart';

enum AppButtonVariant {
  /// The one main action on a screen.
  primary,

  /// Tonal: secondary actions next to a primary one.
  secondary,

  /// Text-only, low emphasis.
  ghost,

  /// Irreversible actions (delete, leave).
  destructive,
}

/// The app's button. Height ≥ 48dp, label always visible, spinner while
/// [isLoading] (the button is disabled meanwhile, so it cannot double-submit).
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final IconData? icon;

  /// Full width (forms, sheets) or intrinsic width (inline).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final (Color bg, Color fg, BorderSide? side) = switch (variant) {
      AppButtonVariant.primary => (t.primary, t.onPrimary, null),
      AppButtonVariant.secondary => (t.secondary, t.textPrimary, null),
      AppButtonVariant.ghost => (Colors.transparent, t.primary, null),
      AppButtonVariant.destructive => (
        t.toneContainer(StatusTone.error),
        t.onToneContainer(StatusTone.error),
        BorderSide(color: t.error.withValues(alpha: 0.4)),
      ),
    };

    final child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  style: t.button.copyWith(color: fg),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          );

    final button = TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(expand ? double.infinity : 64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: variant == AppButtonVariant.ghost
            ? Colors.transparent
            : t.surfaceMuted,
        disabledForegroundColor: t.textSecondary,
        side: side,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.buttonRadius),
        ),
      ),
      child: child,
    );

    // Screen readers hear the label even while the spinner is shown.
    return Semantics(
      button: true,
      label: isLoading ? '$label, loading' : null,
      excludeSemantics: isLoading,
      child: button,
    );
  }
}
