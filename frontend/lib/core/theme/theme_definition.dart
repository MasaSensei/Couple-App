import 'package:flutter/material.dart';

/// Everything a theme defines, as data. New themes are new [ThemeDefinition]
/// values registered in `theme_registry.dart`; no screen code changes.
///
/// Keys (`key`, preset keys) are shared with the backend catalog
/// (`backend/database/data/appearance_catalog.json`), which only stores
/// metadata and validates the couple's choices against them.
@immutable
class ThemeDefinition {
  const ThemeDefinition({
    required this.key,
    required this.name,
    required this.tagline,
    required this.version,
    required this.light,
    this.dark,
    required this.typography,
    this.components = const ThemeComponentStyle(),
    this.decoration = const ThemeDecoration.none(),
    this.animation = const ThemeAnimation.none(),
    this.ornament = OrnamentKind.washiTape,
    this.accentPresets = const [],
    this.backgroundPresets = const [],
    this.fontPresets = const [],
    this.photoBoothTemplates = const {},
  });

  final String key;
  final String name;
  final String tagline;
  final int version;

  final ThemePalette light;

  /// Null when the theme is light-only; the light palette is used in dark mode.
  final ThemePalette? dark;

  final ThemeTypography typography;
  final ThemeComponentStyle components;
  final ThemeDecoration decoration;
  final ThemeAnimation animation;

  /// Small scrapbook touch on memory cards and photo frames (see
  /// `core/widgets/journal/ornament.dart`). Never drawn over text.
  final OrnamentKind ornament;

  /// Controlled customization: the only values a couple can pick.
  final List<AccentPreset> accentPresets;
  final List<BackgroundPreset> backgroundPresets;
  final List<FontPreset> fontPresets;

  /// Photo Booth template keys that suit this theme (shown first).
  final Set<String> photoBoothTemplates;

  bool get supportsDark => dark != null;

  ThemePalette palette(Brightness brightness) =>
      brightness == Brightness.dark ? (dark ?? light) : light;
}

@immutable
class ThemePalette {
  const ThemePalette({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    this.success,
    this.error,
    this.warning,
    this.info,
    this.surfaceMuted,
    this.paper,
  });

  final Brightness brightness;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  // Optional: when null, `AppTheme.resolveTokens` derives an accessible value
  // for the palette's brightness, so older theme files stay valid.
  final Color? success;
  final Color? error;
  final Color? warning;
  final Color? info;

  /// Grouped settings, inputs, skeletons.
  final Color? surfaceMuted;

  /// Photo frame "print" colour (stays light in dark mode, like a photo).
  final Color? paper;

  ThemePalette copyWith({
    Color? primary,
    Color? onPrimary,
    Color? accent,
    Color? background,
    Color? surface,
  }) {
    return ThemePalette(
      brightness: brightness,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      border: border,
      success: success,
      error: error,
      warning: warning,
      info: info,
      surfaceMuted: surfaceMuted,
      paper: paper,
    );
  }
}

@immutable
class ThemeTypography {
  const ThemeTypography({
    this.displayFamily,
    this.bodyFamily,
    this.handwritingFamily = 'DancingScript',
    this.displayWeight = FontWeight.w700,
    this.displayLetterSpacing = 0,
    this.displayScale = 1.0,
  });

  /// Bundled font family names (see pubspec `fonts:`); null = platform default.
  final String? displayFamily;
  final String? bodyFamily;

  /// Short captions and greetings only (never body text or buttons).
  final String handwritingFamily;
  final FontWeight displayWeight;
  final double displayLetterSpacing;

  /// Script/decorative display faces read smaller; scale them up a little.
  final double displayScale;
}

enum NavigationStyle { flat, tinted, elevated }

@immutable
class ThemeComponentStyle {
  const ThemeComponentStyle({
    this.buttonRadius = 20,
    this.cardRadius = 20,
    this.cardElevation = 0,
    this.cardBorder = true,
    this.navigation = NavigationStyle.flat,
    this.chipRadius = 999,
    this.sheetRadius = 28,
    this.photoRadius = 4,
  });

  final double buttonRadius;
  final double cardRadius;
  final double cardElevation;
  final bool cardBorder;
  final NavigationStyle navigation;
  final double chipRadius;
  final double sheetRadius;

  /// Corner of a photo inside its frame.
  final double photoRadius;
}

/// Scrapbook touch per theme, drawn on the edge of memory cards and frames.
enum OrnamentKind {
  none,
  washiTape,
  petal,
  snowflakeStamp,
  star,
  filmSprockets,
  filigree,
  pressedFlower,
  kraftTag,
  goldStar,
}

/// Background ornament painted behind content (see `theme_decorations.dart`).
enum DecorationKind {
  none,
  petals,
  snowflakes,
  stars,
  filmGrain,
  ornaments,
  leaves,
  coffee,
  constellations,
}

@immutable
class ThemeDecoration {
  const ThemeDecoration({
    required this.kind,
    this.density = 1.0,
    this.opacity = 0.18,
  });

  const ThemeDecoration.none()
    : kind = DecorationKind.none,
      density = 0,
      opacity = 0;

  final DecorationKind kind;

  /// Relative amount of ornaments (1.0 = default).
  final double density;

  /// Kept low so ornaments never compete with text.
  final double opacity;
}

enum AnimationKind { none, drift, twinkle, fall }

@immutable
class ThemeAnimation {
  const ThemeAnimation({
    required this.kind,
    this.period = const Duration(seconds: 24),
  });

  const ThemeAnimation.none()
    : kind = AnimationKind.none,
      period = Duration.zero;

  final AnimationKind kind;
  final Duration period;

  bool get isAnimated => kind != AnimationKind.none;
}

@immutable
class AccentPreset {
  const AccentPreset({
    required this.key,
    required this.label,
    required this.primary,
    this.onPrimary = Colors.white,
    this.darkPrimary,
  });

  final String key;
  final String label;
  final Color primary;
  final Color onPrimary;

  /// Lighter variant used on dark backgrounds; defaults to [primary].
  final Color? darkPrimary;
}

@immutable
class BackgroundPreset {
  const BackgroundPreset({
    required this.key,
    required this.label,
    required this.background,
    required this.surface,
    this.darkBackground,
    this.darkSurface,
  });

  final String key;
  final String label;
  final Color background;
  final Color surface;
  final Color? darkBackground;
  final Color? darkSurface;
}

@immutable
class FontPreset {
  const FontPreset({
    required this.key,
    required this.label,
    this.displayFamily,
    this.bodyFamily,
  });

  final String key;
  final String label;
  final String? displayFamily;
  final String? bodyFamily;
}
