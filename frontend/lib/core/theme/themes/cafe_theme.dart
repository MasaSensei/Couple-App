import 'package:flutter/material.dart';

import '../theme_definition.dart';

/// Coffee brown and beige, warm and cosy, with drifting steam and beans.
const cafeTheme = ThemeDefinition(
  key: 'cafe',
  name: 'Café',
  tagline: 'Coffee, beige and the warmth of your favourite corner table.',
  version: 1,
  light: ThemePalette(
    brightness: Brightness.light,
    primary: Color(0xFF6F4E37),
    onPrimary: Color(0xFFFFFAF4),
    secondary: Color(0xFFE7D7C3),
    accent: Color(0xFFC8A27A),
    background: Color(0xFFF6EFE6),
    surface: Color(0xFFFFFBF6),
    textPrimary: Color(0xFF2F241C),
    textSecondary: Color(0xFF66574A),
    border: Color(0xFFE6D9C8),
  ),
  dark: ThemePalette(
    brightness: Brightness.dark,
    primary: Color(0xFFD7B08A),
    onPrimary: Color(0xFF2B1D12),
    secondary: Color(0xFF45372C),
    accent: Color(0xFFE6C8A8),
    background: Color(0xFF1B1512),
    surface: Color(0xFF27201B),
    textPrimary: Color(0xFFF3EBE2),
    textSecondary: Color(0xFFC3B3A2),
    border: Color(0xFF403329),
  ),
  typography: ThemeTypography(
    displayFamily: 'PlayfairDisplay',
    bodyFamily: 'Nunito',
    displayWeight: FontWeight.w700,
  ),
  components: ThemeComponentStyle(
    buttonRadius: 16,
    cardRadius: 16,
    cardElevation: 1,
    navigation: NavigationStyle.elevated,
  ),
  decoration: ThemeDecoration(
    kind: DecorationKind.coffee,
    density: 0.8,
    opacity: 0.16,
  ),
  animation: ThemeAnimation(
    kind: AnimationKind.drift,
    period: Duration(seconds: 20),
  ),
  accentPresets: [
    AccentPreset(
      key: 'espresso',
      label: 'Espresso',
      primary: Color(0xFF6F4E37),
      onPrimary: Color(0xFFFFFAF4),
      darkPrimary: Color(0xFFD7B08A),
    ),
    AccentPreset(
      key: 'mocha',
      label: 'Mocha',
      primary: Color(0xFF7A3E2B),
      onPrimary: Color(0xFFFFFAF4),
      darkPrimary: Color(0xFFE8A88C),
    ),
    AccentPreset(
      key: 'matcha',
      label: 'Matcha',
      primary: Color(0xFF4C6B3C),
      onPrimary: Color(0xFFFFFAF4),
      darkPrimary: Color(0xFFB4D19A),
    ),
  ],
  backgroundPresets: [
    BackgroundPreset(
      key: 'latte',
      label: 'Latte',
      background: Color(0xFFF6EFE6),
      surface: Color(0xFFFFFBF6),
    ),
    BackgroundPreset(
      key: 'oat',
      label: 'Oat milk',
      background: Color(0xFFF7F3EA),
      surface: Colors.white,
      darkBackground: Color(0xFF1A1714),
      darkSurface: Color(0xFF26221E),
    ),
  ],
  fontPresets: [
    FontPreset(
      key: 'menu',
      label: 'Café menu',
      displayFamily: 'PlayfairDisplay',
      bodyFamily: 'Nunito',
    ),
    FontPreset(
      key: 'notebook',
      label: 'Notebook',
      displayFamily: 'Lora',
      bodyFamily: 'Lora',
    ),
  ],
  photoBoothTemplates: {
    'classic_4',
    'vertical_strip',
    'polaroid',
    'vintage_film',
  },
);
