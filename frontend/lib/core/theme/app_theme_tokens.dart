import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'theme_customization.dart';
import 'theme_definition.dart';

/// The resolved theme (definition + customization + brightness) that widgets
/// read through `context.tokens`. Lerps, so theme changes animate instead of
/// rebuilding the app.
@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.themeKey,
    required this.primary,
    required this.primaryDark,
    required this.onPrimary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.success,
    required this.error,
    required this.display,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.button,
    required this.cardRadius,
    required this.buttonRadius,
    required this.cardBorder,
    required this.cardElevation,
    required this.navigation,
    required this.decoration,
    required this.animation,
    required this.decorationsEnabled,
    required this.animationsEnabled,
    required this.coupleSpaceStyle,
    required this.memoryStyle,
  });

  /// The original look (pre-Phase 7 constants). Used when a widget is built
  /// outside the app theme, e.g. in isolated widget tests.
  static const fallback = AppThemeTokens(
    themeKey: 'classic_rose',
    primary: AppColors.primary,
    primaryDark: AppColors.primaryDark,
    onPrimary: Colors.white,
    secondary: AppColors.secondary,
    accent: AppColors.secondary,
    background: AppColors.background,
    surface: AppColors.surface,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    border: AppColors.border,
    success: AppColors.success,
    error: AppColors.error,
    display: AppTextStyles.display,
    title: AppTextStyles.title,
    subtitle: AppTextStyles.subtitle,
    body: AppTextStyles.body,
    button: AppTextStyles.button,
    cardRadius: 20,
    buttonRadius: 20,
    cardBorder: true,
    cardElevation: 0,
    navigation: NavigationStyle.flat,
    decoration: ThemeDecoration.none(),
    animation: ThemeAnimation.none(),
    decorationsEnabled: false,
    animationsEnabled: false,
    coupleSpaceStyle: CoupleSpaceStyle.classic,
    memoryStyle: MemoryStyle.soft,
  );

  final String themeKey;

  final Color primary;
  final Color primaryDark;
  final Color onPrimary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color success;
  final Color error;

  final TextStyle display;
  final TextStyle title;
  final TextStyle subtitle;
  final TextStyle body;
  final TextStyle button;

  final double cardRadius;
  final double buttonRadius;
  final bool cardBorder;
  final double cardElevation;
  final NavigationStyle navigation;

  final ThemeDecoration decoration;
  final ThemeAnimation animation;

  /// Theme ornaments after the couple's toggle (never forced on).
  final bool decorationsEnabled;

  /// Theme motion after the couple's toggle; screens also honour the
  /// platform "reduce motion" setting and the user's own preference.
  final bool animationsEnabled;

  final CoupleSpaceStyle coupleSpaceStyle;
  final MemoryStyle memoryStyle;

  @override
  AppThemeTokens copyWith({bool? decorationsEnabled, bool? animationsEnabled}) {
    return _with(
      decorationsEnabled: decorationsEnabled,
      animationsEnabled: animationsEnabled,
    );
  }

  AppThemeTokens _with({bool? decorationsEnabled, bool? animationsEnabled}) =>
      AppThemeTokens(
        themeKey: themeKey,
        primary: primary,
        primaryDark: primaryDark,
        onPrimary: onPrimary,
        secondary: secondary,
        accent: accent,
        background: background,
        surface: surface,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        border: border,
        success: success,
        error: error,
        display: display,
        title: title,
        subtitle: subtitle,
        body: body,
        button: button,
        cardRadius: cardRadius,
        buttonRadius: buttonRadius,
        cardBorder: cardBorder,
        cardElevation: cardElevation,
        navigation: navigation,
        decoration: decoration,
        animation: animation,
        decorationsEnabled: decorationsEnabled ?? this.decorationsEnabled,
        animationsEnabled: animationsEnabled ?? this.animationsEnabled,
        coupleSpaceStyle: coupleSpaceStyle,
        memoryStyle: memoryStyle,
      );

  @override
  AppThemeTokens lerp(covariant AppThemeTokens? other, double t) {
    if (other == null) return this;

    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    TextStyle s(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    final discrete = t < 0.5 ? this : other;

    return AppThemeTokens(
      themeKey: discrete.themeKey,
      primary: c(primary, other.primary),
      primaryDark: c(primaryDark, other.primaryDark),
      onPrimary: c(onPrimary, other.onPrimary),
      secondary: c(secondary, other.secondary),
      accent: c(accent, other.accent),
      background: c(background, other.background),
      surface: c(surface, other.surface),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      border: c(border, other.border),
      success: c(success, other.success),
      error: c(error, other.error),
      display: s(display, other.display),
      title: s(title, other.title),
      subtitle: s(subtitle, other.subtitle),
      body: s(body, other.body),
      button: s(button, other.button),
      cardRadius: cardRadius + (other.cardRadius - cardRadius) * t,
      buttonRadius: buttonRadius + (other.buttonRadius - buttonRadius) * t,
      cardBorder: discrete.cardBorder,
      cardElevation: cardElevation + (other.cardElevation - cardElevation) * t,
      navigation: discrete.navigation,
      decoration: discrete.decoration,
      animation: discrete.animation,
      decorationsEnabled: discrete.decorationsEnabled,
      animationsEnabled: discrete.animationsEnabled,
      coupleSpaceStyle: discrete.coupleSpaceStyle,
      memoryStyle: discrete.memoryStyle,
    );
  }
}

extension AppThemeTokensContext on BuildContext {
  AppThemeTokens get tokens =>
      Theme.of(this).extension<AppThemeTokens>() ?? AppThemeTokens.fallback;
}
