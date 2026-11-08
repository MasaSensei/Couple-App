import 'package:flutter/material.dart';

import '../theme_definition.dart';

/// Warm brown and cream, typewriter headings, film grain and sharp prints.
const vintageFilmTheme = ThemeDefinition(
  key: 'vintage_film',
  name: 'Vintage Film',
  tagline: 'Warm analog tones, like prints from an old camera.',
  version: 1,
  light: ThemePalette(
    brightness: Brightness.light,
    primary: Color(0xFF7A4B2A),
    onPrimary: Color(0xFFFFF8EC),
    secondary: Color(0xFFD9C3A0),
    accent: Color(0xFFB5651D),
    background: Color(0xFFF4ECDD),
    surface: Color(0xFFFBF6EC),
    textPrimary: Color(0xFF3B2A1E),
    textSecondary: Color(0xFF6B5544),
    border: Color(0xFFE0D2BA),
  ),
  dark: ThemePalette(
    brightness: Brightness.dark,
    primary: Color(0xFFD9A86C),
    onPrimary: Color(0xFF2A1A0C),
    secondary: Color(0xFF4A3A2A),
    accent: Color(0xFFE6B680),
    background: Color(0xFF1C1611),
    surface: Color(0xFF2A221A),
    textPrimary: Color(0xFFF1E6D4),
    textSecondary: Color(0xFFC2B19A),
    border: Color(0xFF43372A),
  ),
  typography: ThemeTypography(
    displayFamily: 'CourierPrime',
    bodyFamily: 'Lora',
    handwritingFamily: 'CourierPrime',
    displayWeight: FontWeight.w700,
  ),
  components: ThemeComponentStyle(
    buttonRadius: 8,
    cardRadius: 6,
    photoRadius: 0,
    cardElevation: 2,
    cardBorder: false,
    navigation: NavigationStyle.elevated,
  ),
  ornament: OrnamentKind.filmSprockets,
  decoration: ThemeDecoration(
    kind: DecorationKind.filmGrain,
    density: 1.0,
    opacity: 0.10,
  ),
  accentPresets: [
    AccentPreset(
      key: 'sepia',
      label: 'Sepia',
      primary: Color(0xFF7A4B2A),
      onPrimary: Color(0xFFFFF8EC),
      darkPrimary: Color(0xFFD9A86C),
    ),
    AccentPreset(
      key: 'kodak',
      label: 'Amber',
      primary: Color(0xFF8A4B0F),
      onPrimary: Color(0xFFFFF8EC),
      darkPrimary: Color(0xFFF0B45E),
    ),
    AccentPreset(
      key: 'faded_teal',
      label: 'Faded teal',
      primary: Color(0xFF2F5D5A),
      onPrimary: Color(0xFFFFF8EC),
      darkPrimary: Color(0xFF8FC6BF),
    ),
  ],
  backgroundPresets: [
    BackgroundPreset(
      key: 'cream',
      label: 'Cream',
      background: Color(0xFFF4ECDD),
      surface: Color(0xFFFBF6EC),
    ),
    BackgroundPreset(
      key: 'paper',
      label: 'Old paper',
      background: Color(0xFFEFE3CB),
      surface: Color(0xFFF8F0DE),
      darkBackground: Color(0xFF211A12),
      darkSurface: Color(0xFF30271C),
    ),
  ],
  fontPresets: [
    FontPreset(
      key: 'typewriter',
      label: 'Typewriter',
      displayFamily: 'CourierPrime',
      bodyFamily: 'Lora',
    ),
    FontPreset(
      key: 'book',
      label: 'Book',
      displayFamily: 'Lora',
      bodyFamily: 'Lora',
    ),
  ],
  photoBoothTemplates: {
    'vintage_film',
    'polaroid',
    'vertical_strip',
    'classic_3',
  },
);
