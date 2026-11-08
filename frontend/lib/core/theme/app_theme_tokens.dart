import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'theme_customization.dart';
import 'theme_definition.dart';

/// Semantic tone for status chips, banners and badges.
enum StatusTone { neutral, brand, success, warning, error, info }

/// The resolved theme (definition + customization + brightness) that widgets
/// read through `context.tokens`. Lerps, so theme changes animate instead of
/// rebuilding the app.
@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.themeKey,
    required this.brightness,
    required this.primary,
    required this.primaryDark,
    required this.onPrimary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.paper,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.display,
    required this.title,
    required this.heading,
    required this.subtitle,
    required this.body,
    required this.label,
    required this.caption,
    required this.overline,
    required this.handwriting,
    required this.button,
    required this.cardRadius,
    required this.buttonRadius,
    required this.chipRadius,
    required this.sheetRadius,
    required this.photoRadius,
    required this.cardBorder,
    required this.cardElevation,
    required this.navigation,
    required this.ornament,
    required this.ornamentsEnabled,
    required this.decoration,
    required this.animation,
    required this.decorationsEnabled,
    required this.animationsEnabled,
    required this.reduceMotion,
    required this.coupleSpaceStyle,
    required this.memoryStyle,
  });

  /// The brand look (Classic Rose, light). Used when a widget is built
  /// outside the app theme, e.g. in isolated widget tests.
  static const fallback = AppThemeTokens(
    themeKey: 'classic_rose',
    brightness: Brightness.light,
    primary: AppColors.primary,
    primaryDark: AppColors.primaryDark,
    onPrimary: Colors.white,
    secondary: AppColors.secondary,
    accent: AppColors.accent,
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceMuted: AppColors.surfaceMuted,
    paper: AppColors.paper,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    border: AppColors.border,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
    info: AppColors.info,
    display: AppTextStyles.display,
    title: AppTextStyles.title,
    heading: AppTextStyles.heading,
    subtitle: AppTextStyles.subtitle,
    body: AppTextStyles.body,
    label: AppTextStyles.label,
    caption: AppTextStyles.caption,
    overline: AppTextStyles.overline,
    handwriting: AppTextStyles.handwriting,
    button: AppTextStyles.button,
    cardRadius: 20,
    buttonRadius: 16,
    chipRadius: 999,
    sheetRadius: 28,
    photoRadius: 4,
    cardBorder: true,
    cardElevation: 0,
    navigation: NavigationStyle.tinted,
    ornament: OrnamentKind.washiTape,
    ornamentsEnabled: true,
    decoration: ThemeDecoration.none(),
    animation: ThemeAnimation.none(),
    decorationsEnabled: false,
    animationsEnabled: false,
    reduceMotion: false,
    coupleSpaceStyle: CoupleSpaceStyle.classic,
    memoryStyle: MemoryStyle.soft,
  );

  final String themeKey;
  final Brightness brightness;

  final Color primary;
  final Color primaryDark;
  final Color onPrimary;
  final Color secondary;

  /// Decorative only (stamps, stars, dots). Not guaranteed to pass text contrast.
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceMuted;

  /// Photo "print" colour for polaroid frames; text on it uses [onPaper].
  final Color paper;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  final TextStyle display;
  final TextStyle title;
  final TextStyle heading;
  final TextStyle subtitle;
  final TextStyle body;
  final TextStyle label;
  final TextStyle caption;
  final TextStyle overline;

  /// Short captions and greetings only.
  final TextStyle handwriting;
  final TextStyle button;

  final double cardRadius;
  final double buttonRadius;
  final double chipRadius;
  final double sheetRadius;
  final double photoRadius;
  final bool cardBorder;
  final double cardElevation;
  final NavigationStyle navigation;
  final OrnamentKind ornament;

  /// Card/frame ornaments after the couple's "decorations" toggle.
  final bool ornamentsEnabled;

  final ThemeDecoration decoration;
  final ThemeAnimation animation;

  /// Theme ornaments after the couple's toggle (never forced on).
  final bool decorationsEnabled;

  /// Theme motion after the couple's toggle; screens also honour the
  /// platform "reduce motion" setting and the user's own preference.
  final bool animationsEnabled;

  /// The user's personal "Reduce motion" preference (this device only).
  /// Read through `context.motion`, which also honours the platform setting.
  final bool reduceMotion;

  final CoupleSpaceStyle coupleSpaceStyle;
  final MemoryStyle memoryStyle;

  bool get isDark => brightness == Brightness.dark;

  /// Ink on [paper]; photo prints stay light even in dark themes.
  Color get onPaper => const Color(0xFF34262B);

  /// Ink-tinted shadows (never pure black). In dark mode shadows are almost
  /// invisible, so cards rely on [border] instead.
  List<BoxShadow> elevation(int level) {
    if (level <= 0) return const [];
    final ink = isDark ? Colors.black : textPrimary;
    return switch (level) {
      1 => [
        BoxShadow(
          color: ink.withValues(alpha: isDark ? 0.30 : 0.06),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: ink.withValues(alpha: isDark ? 0.20 : 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      2 => [
        BoxShadow(
          color: ink.withValues(alpha: isDark ? 0.40 : 0.09),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
      _ => [
        BoxShadow(
          color: ink.withValues(alpha: isDark ? 0.50 : 0.12),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ],
    };
  }

  Color _toneBase(StatusTone tone) => switch (tone) {
    StatusTone.neutral => textSecondary,
    StatusTone.brand => primary,
    StatusTone.success => success,
    StatusTone.warning => warning,
    StatusTone.error => error,
    StatusTone.info => info,
  };

  /// Soft fill for a status chip or banner, opaque so contrast is predictable.
  Color toneContainer(StatusTone tone) => tone == StatusTone.neutral
      ? surfaceMuted
      : Color.alphaBlend(
          _toneBase(tone).withValues(alpha: isDark ? 0.18 : 0.12),
          surface,
        );

  /// Text/icon colour on [toneContainer]: the tone pulled towards the text
  /// colour so it reads at 4.5:1 on every theme (covered by tests).
  Color onToneContainer(StatusTone tone) => tone == StatusTone.neutral
      ? textSecondary
      : Color.lerp(_toneBase(tone), textPrimary, 0.3)!;

  /// Solid colour for icons and progress bars in that tone.
  Color tone(StatusTone tone) => _toneBase(tone);

  @override
  AppThemeTokens copyWith({
    bool? decorationsEnabled,
    bool? animationsEnabled,
    bool? reduceMotion,
  }) {
    return AppThemeTokens(
      themeKey: themeKey,
      brightness: brightness,
      primary: primary,
      primaryDark: primaryDark,
      onPrimary: onPrimary,
      secondary: secondary,
      accent: accent,
      background: background,
      surface: surface,
      surfaceMuted: surfaceMuted,
      paper: paper,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      border: border,
      success: success,
      warning: warning,
      error: error,
      info: info,
      display: display,
      title: title,
      heading: heading,
      subtitle: subtitle,
      body: body,
      label: label,
      caption: caption,
      overline: overline,
      handwriting: handwriting,
      button: button,
      cardRadius: cardRadius,
      buttonRadius: buttonRadius,
      chipRadius: chipRadius,
      sheetRadius: sheetRadius,
      photoRadius: photoRadius,
      cardBorder: cardBorder,
      cardElevation: cardElevation,
      navigation: navigation,
      ornament: ornament,
      ornamentsEnabled: ornamentsEnabled,
      decoration: decoration,
      animation: animation,
      decorationsEnabled: decorationsEnabled ?? this.decorationsEnabled,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      coupleSpaceStyle: coupleSpaceStyle,
      memoryStyle: memoryStyle,
    );
  }

  @override
  AppThemeTokens lerp(covariant AppThemeTokens? other, double t) {
    if (other == null) return this;

    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    TextStyle s(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    double d(double a, double b) => a + (b - a) * t;
    final discrete = t < 0.5 ? this : other;

    return AppThemeTokens(
      themeKey: discrete.themeKey,
      brightness: discrete.brightness,
      primary: c(primary, other.primary),
      primaryDark: c(primaryDark, other.primaryDark),
      onPrimary: c(onPrimary, other.onPrimary),
      secondary: c(secondary, other.secondary),
      accent: c(accent, other.accent),
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceMuted: c(surfaceMuted, other.surfaceMuted),
      paper: c(paper, other.paper),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      border: c(border, other.border),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      error: c(error, other.error),
      info: c(info, other.info),
      display: s(display, other.display),
      title: s(title, other.title),
      heading: s(heading, other.heading),
      subtitle: s(subtitle, other.subtitle),
      body: s(body, other.body),
      label: s(label, other.label),
      caption: s(caption, other.caption),
      overline: s(overline, other.overline),
      handwriting: s(handwriting, other.handwriting),
      button: s(button, other.button),
      cardRadius: d(cardRadius, other.cardRadius),
      buttonRadius: d(buttonRadius, other.buttonRadius),
      chipRadius: d(chipRadius, other.chipRadius),
      sheetRadius: d(sheetRadius, other.sheetRadius),
      photoRadius: d(photoRadius, other.photoRadius),
      cardBorder: discrete.cardBorder,
      cardElevation: d(cardElevation, other.cardElevation),
      navigation: discrete.navigation,
      ornament: discrete.ornament,
      ornamentsEnabled: discrete.ornamentsEnabled,
      decoration: discrete.decoration,
      animation: discrete.animation,
      decorationsEnabled: discrete.decorationsEnabled,
      animationsEnabled: discrete.animationsEnabled,
      reduceMotion: discrete.reduceMotion,
      coupleSpaceStyle: discrete.coupleSpaceStyle,
      memoryStyle: discrete.memoryStyle,
    );
  }
}

extension AppThemeTokensContext on BuildContext {
  AppThemeTokens get tokens =>
      Theme.of(this).extension<AppThemeTokens>() ?? AppThemeTokens.fallback;
}
