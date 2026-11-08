import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_tokens.dart';

/// A titled group of [SettingsTile]s on a muted surface, separated by
/// hairlines (iOS/Android settings pattern, tuned to the theme).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    required this.children,
    super.key,
    this.title,
    this.footer,
  });

  final String? title;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(t.cardRadius * 0.8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              0,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Semantics(
              header: true,
              child: Text(title!.toUpperCase(), style: t.overline),
            ),
          ),
        ClipRRect(
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: radius,
              border: Border.all(color: t.border),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) Divider(height: 1, indent: 56, color: t.border),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.xs,
              0,
            ),
            child: Text(footer!, style: t.caption),
          ),
      ],
    );
  }
}

/// One settings row: icon, title, optional subtitle and trailing value or
/// control. Minimum height 56dp.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.title,
    super.key,
    this.icon,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;

  /// Short current value shown before the chevron ("Sakura", "Free").
  final String? value;

  /// Custom trailing widget (e.g. a Switch); replaces value + chevron.
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = destructive
        ? t.onToneContainer(StatusTone.error)
        : t.textPrimary;

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.smd,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: destructive
                        ? t.toneContainer(StatusTone.error)
                        : t.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: destructive ? color : t.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.smd),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: t.caption),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else ...[
                if (value != null)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: Text(value!, style: t.caption),
                  ),
                if (onTap != null)
                  Icon(Icons.chevron_right_rounded, color: t.textSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
