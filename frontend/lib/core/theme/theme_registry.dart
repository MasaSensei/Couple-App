import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'theme_definition.dart';
import 'themes/built_in_themes.dart';

/// All themes the app knows how to draw. The backend catalog decides which of
/// them are *available*; a key the app does not know (newer server, older
/// app) resolves to [defaultTheme] instead of failing.
abstract final class ThemeRegistry {
  static const defaultKey = 'classic_rose';

  /// The original look of the app, kept identical so existing couples see no change.
  static const defaultTheme = ThemeDefinition(
    key: defaultKey,
    name: 'Classic Rose',
    tagline: 'The original soft rose look.',
    version: 1,
    light: ThemePalette(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Color(0xFFFFFFFF),
      secondary: AppColors.secondary,
      accent: AppColors.secondary,
      background: AppColors.background,
      surface: AppColors.surface,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      border: AppColors.border,
      success: AppColors.success,
      error: AppColors.error,
    ),
    typography: ThemeTypography(),
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
