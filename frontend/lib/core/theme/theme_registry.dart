import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'theme_definition.dart';
import 'themes/built_in_themes.dart';

/// All themes the app knows how to draw. The backend catalog decides which of
/// them are *available*; a key the app does not know (newer server, older
/// app) resolves to [defaultTheme] instead of failing.
abstract final class ThemeRegistry {
  static const defaultKey = 'classic_rose';

  /// The brand look ("paper, ink and rosewood"). The key is unchanged so
  /// couples who never picked a theme keep the default after the redesign.
  static const defaultTheme = ThemeDefinition(
    key: defaultKey,
    name: 'Classic Rose',
    tagline: 'Warm paper, rosewood ink and washi tape on your memories.',
    version: 1,
    light: ThemePalette(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Color(0xFFFFFFFF),
      secondary: AppColors.secondary,
      accent: AppColors.accent,
      background: AppColors.background,
      surface: AppColors.surface,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      border: AppColors.border,
      success: AppColors.success,
      error: AppColors.error,
      warning: AppColors.warning,
      info: AppColors.info,
      surfaceMuted: AppColors.surfaceMuted,
      paper: AppColors.paper,
    ),
    dark: ThemePalette(
      brightness: Brightness.dark,
      primary: AppColors.primaryOnDark,
      onPrimary: AppColors.onPrimaryDark,
      secondary: AppColors.secondaryDark,
      accent: AppColors.accentDark,
      background: AppColors.backgroundDark,
      surface: AppColors.surfaceDark,
      textPrimary: AppColors.textPrimaryDark,
      textSecondary: AppColors.textSecondaryDark,
      border: AppColors.borderDark,
      success: AppColors.successDark,
      error: AppColors.errorDark,
      warning: AppColors.warningDark,
      info: AppColors.infoDark,
      surfaceMuted: AppColors.surfaceMutedDark,
      paper: AppColors.paperDark,
    ),
    typography: ThemeTypography(
      displayFamily: AppTextStyles.displayFamily,
      bodyFamily: AppTextStyles.bodyFamily,
      displayWeight: FontWeight.w600,
    ),
    components: ThemeComponentStyle(
      buttonRadius: 16,
      cardRadius: 20,
      navigation: NavigationStyle.tinted,
    ),
    ornament: OrnamentKind.washiTape,
    photoBoothTemplates: {'classic_2', 'classic_3', 'classic_4', 'polaroid'},
  );

  static final List<ThemeDefinition> all = List.unmodifiable([
    defaultTheme,
    ...builtInThemes,
  ]);

  static final Map<String, ThemeDefinition> _byKey = {
    for (final theme in all) theme.key: theme,
  };

  static ThemeDefinition byKey(String? key) => _byKey[key] ?? defaultTheme;

  static bool contains(String? key) => _byKey.containsKey(key);
}
