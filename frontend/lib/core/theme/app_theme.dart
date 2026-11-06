import 'package:flutter/material.dart';

import 'app_theme_tokens.dart';
import 'theme_customization.dart';
import 'theme_definition.dart';
import 'theme_registry.dart';

abstract final class AppTheme {
  /// The pre-Phase 7 theme, unchanged.
  static ThemeData light() => build(ThemeRegistry.defaultTheme, Brightness.light);

  /// Resolves a theme definition + the couple's customization into
  /// [ThemeData] carrying [AppThemeTokens]. Unknown preset keys fall back to
  /// the theme defaults, so a stale or tampered setting can never break UI.
  static ThemeData build(
    ThemeDefinition definition,
    Brightness brightness, {
    ThemeCustomization customization = ThemeCustomization.defaults,
  }) {
    // Dark-only themes (Midnight, Starry Night) stay dark in light mode.
    brightness = definition.palette(brightness).brightness;
    final tokens = resolveTokens(definition, brightness, customization: customization);
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: tokens.primary,
      brightness: brightness,
    ).copyWith(
      primary: tokens.primary,
      onPrimary: tokens.onPrimary,
      secondary: tokens.secondary,
      surface: tokens.surface,
      onSurface: tokens.textPrimary,
      error: tokens.error,
      outline: tokens.border,
    );

    final appBarColor = switch (tokens.navigation) {
      NavigationStyle.flat => tokens.background,
      NavigationStyle.tinted => Color.alphaBlend(tokens.primary.withValues(alpha: isDark ? 0.18 : 0.10), tokens.background),
      NavigationStyle.elevated => tokens.surface,
    };

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.background,
      fontFamily: tokens.body.fontFamily,
      extensions: [tokens],

      textTheme: TextTheme(
        displayLarge: tokens.display,
        headlineMedium: tokens.title,
        titleLarge: tokens.title.copyWith(fontSize: 22),
        titleMedium: tokens.body.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: tokens.body,
        bodyMedium: tokens.body,
        bodySmall: tokens.body.copyWith(fontSize: 13, color: tokens.textSecondary),
        labelLarge: tokens.button.copyWith(color: null),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: appBarColor,
        foregroundColor: tokens.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: tokens.navigation == NavigationStyle.elevated ? 1 : 0,
        scrolledUnderElevation: tokens.navigation == NavigationStyle.flat ? 0 : 2,
        titleTextStyle: tokens.title.copyWith(fontSize: 20),
      ),

      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: tokens.cardElevation,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.cardRadius),
          side: tokens.cardBorder ? BorderSide(color: tokens.border) : BorderSide.none,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.buttonRadius),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.buttonRadius),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.buttonRadius),
          borderSide: BorderSide(color: tokens.primary, width: 1.5),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          backgroundColor: tokens.primary,
          foregroundColor: tokens.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.buttonRadius)),
          textStyle: tokens.button,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.buttonRadius)),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tokens.primary,
        foregroundColor: tokens.onPrimary,
      ),

      chipTheme: ChipThemeData(
        selectedColor: tokens.primary.withValues(alpha: 0.18),
        side: BorderSide(color: tokens.border),
        labelStyle: tokens.body.copyWith(fontSize: 13),
      ),

      dividerColor: tokens.border,
    );
  }

  static AppThemeTokens resolveTokens(
    ThemeDefinition definition,
    Brightness brightness, {
    ThemeCustomization customization = ThemeCustomization.defaults,
  }) {
    final isDark = brightness == Brightness.dark;
    var palette = definition.palette(brightness);

    final accent = definition.accentPresets.where((p) => p.key == customization.accent).firstOrNull;
    if (accent != null) {
      // In dark mode accents switch to a lighter variant, which needs the dark
      // palette's (dark) text colour on top of it, not the light one.
      palette = isDark && accent.darkPrimary != null
          ? palette.copyWith(primary: accent.darkPrimary, onPrimary: definition.palette(Brightness.dark).onPrimary)
          : palette.copyWith(primary: accent.primary, onPrimary: accent.onPrimary);
    }

    final background = definition.backgroundPresets.where((p) => p.key == customization.background).firstOrNull;
    if (background != null) {
      palette = palette.copyWith(
        background: isDark ? (background.darkBackground ?? palette.background) : background.background,
        surface: isDark ? (background.darkSurface ?? palette.surface) : background.surface,
      );
    }

    final font = definition.fontPresets.where((p) => p.key == customization.font).firstOrNull;
    final typography = definition.typography;
    final displayFamily = font?.displayFamily ?? typography.displayFamily;
    final bodyFamily = font?.bodyFamily ?? typography.bodyFamily;

    TextStyle style(String? family, double size, FontWeight weight, Color color, double height, {double spacing = 0}) {
      return TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        // Bundled fonts are variable fonts: drive the weight axis explicitly.
        fontVariations: family == null ? null : [FontVariation('wght', weight.value.toDouble())],
        letterSpacing: spacing,
        color: color,
        height: height,
      );
    }

    final scale = font?.displayFamily != null ? 1.0 : typography.displayScale;

    return AppThemeTokens(
      themeKey: definition.key,
      primary: palette.primary,
      primaryDark: Color.lerp(palette.primary, Colors.black, 0.12)!,
      onPrimary: palette.onPrimary,
      secondary: palette.secondary,
      accent: palette.accent,
      background: palette.background,
      surface: palette.surface,
      textPrimary: palette.textPrimary,
      textSecondary: palette.textSecondary,
      border: palette.border,
      success: palette.success,
      error: palette.error,
      display: style(displayFamily, 32 * scale, typography.displayWeight, palette.textPrimary, 1.2, spacing: typography.displayLetterSpacing),
      title: style(displayFamily, 24 * scale, typography.displayWeight, palette.textPrimary, 1.25, spacing: typography.displayLetterSpacing),
      subtitle: style(bodyFamily, 16, FontWeight.w400, palette.textSecondary, 1.5),
      body: style(bodyFamily, 15, FontWeight.w400, palette.textPrimary, 1.5),
      button: style(bodyFamily, 15, FontWeight.w600, palette.onPrimary, 1.2),
      cardRadius: definition.components.cardRadius,
      buttonRadius: definition.components.buttonRadius,
      cardBorder: definition.components.cardBorder,
      cardElevation: definition.components.cardElevation,
      navigation: definition.components.navigation,
      decoration: definition.decoration,
      animation: definition.animation,
      decorationsEnabled: customization.decorations && definition.decoration.kind != DecorationKind.none,
      animationsEnabled: customization.animations && definition.animation.isAnimated,
      coupleSpaceStyle: customization.coupleSpaceStyle,
      memoryStyle: customization.memoryStyle,
    );
  }
}
