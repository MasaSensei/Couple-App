import 'package:flutter/material.dart';

import '../theme_definition.dart';

/// Natural green and warm cream with drifting botanical leaves.
const cottageTheme = ThemeDefinition(
  key: 'cottage',
  name: 'Cottage',
  tagline: 'Moss, cream and wildflowers from a garden cottage.',
  version: 1,
  light: ThemePalette(
    brightness: Brightness.light,
    primary: Color(0xFF4F6B3A),
    onPrimary: Colors.white,
    secondary: Color(0xFFDCE5C8),
    accent: Color(0xFFC9876B),
    background: Color(0xFFF5F1E6),
    surface: Color(0xFFFFFDF7),
    textPrimary: Color(0xFF2E3426),
    textSecondary: Color(0xFF5E6651),
    border: Color(0xFFE2DCC8),
  ),
  dark: ThemePalette(
    brightness: Brightness.dark,
    primary: Color(0xFFA9C48C),
    onPrimary: Color(0xFF1C2614),
    secondary: Color(0xFF34402A),
    accent: Color(0xFFE0A88F),
    background: Color(0xFF161A12),
    surface: Color(0xFF20261A),
    textPrimary: Color(0xFFEEF0E4),
    textSecondary: Color(0xFFB9C0A8),
    border: Color(0xFF343D2A),
  ),
  typography: ThemeTypography(
    displayFamily: 'Lora',
    bodyFamily: 'Nunito',
    displayWeight: FontWeight.w600,
  ),
  components: ThemeComponentStyle(
    buttonRadius: 22,
    cardRadius: 22,
    navigation: NavigationStyle.tinted,
  ),
  decoration: ThemeDecoration(
    kind: DecorationKind.leaves,
    density: 0.9,
    opacity: 0.20,
  ),
  animation: ThemeAnimation(
    kind: AnimationKind.drift,
    period: Duration(seconds: 32),
  ),
  accentPresets: [
    AccentPreset(
      key: 'moss',
      label: 'Moss',
      primary: Color(0xFF4F6B3A),
      darkPrimary: Color(0xFFA9C48C),
    ),
    AccentPreset(
      key: 'terracotta',
      label: 'Terracotta',
      primary: Color(0xFF9A4A2E),
      darkPrimary: Color(0xFFE0A88F),
    ),
    AccentPreset(
      key: 'lavender',
      label: 'Lavender field',
      primary: Color(0xFF5E4E85),
      darkPrimary: Color(0xFFC3B4E6),
    ),
  ],
  backgroundPresets: [
    BackgroundPreset(
      key: 'cream',
      label: 'Cream',
      background: Color(0xFFF5F1E6),
      surface: Color(0xFFFFFDF7),
    ),
    BackgroundPreset(
      key: 'sage',
      label: 'Sage',
      background: Color(0xFFEFF3E8),
      surface: Color(0xFFFBFDF8),
      darkBackground: Color(0xFF12170F),
      darkSurface: Color(0xFF1C2318),
    ),
  ],
  fontPresets: [
    FontPreset(
      key: 'storybook',
      label: 'Storybook',
      displayFamily: 'Lora',
      bodyFamily: 'Nunito',
    ),
    FontPreset(
      key: 'simple',
      label: 'Simple',
      displayFamily: 'Nunito',
      bodyFamily: 'Nunito',
    ),
  ],
  photoBoothTemplates: {'polaroid', 'classic_3', 'classic_2', 'romantic_frame'},
);
