import 'package:flutter/material.dart';

import '../theme_definition.dart';

/// Soft pink, floral, romantic: script headings and falling petals.
const sakuraTheme = ThemeDefinition(
  key: 'sakura',
  name: 'Sakura',
  tagline: 'Soft pink blossoms drifting through your space.',
  version: 1,
  light: ThemePalette(
    brightness: Brightness.light,
    primary: Color(0xFFB83B5E),
    onPrimary: Colors.white,
    secondary: Color(0xFFF7C6D3),
    accent: Color(0xFFE38BA6),
    background: Color(0xFFFFF5F7),
    surface: Colors.white,
    textPrimary: Color(0xFF3D2530),
    textSecondary: Color(0xFF7A5563),
    border: Color(0xFFF3D3DD),
  ),
  dark: ThemePalette(
    brightness: Brightness.dark,
    primary: Color(0xFFF08FAE),
    onPrimary: Color(0xFF3A0F1E),
    secondary: Color(0xFF5A2F40),
    accent: Color(0xFFF7B6C9),
    background: Color(0xFF1E1418),
    surface: Color(0xFF2A1D22),
    textPrimary: Color(0xFFF9E8EE),
    textSecondary: Color(0xFFD1AEBB),
    border: Color(0xFF4A333C),
  ),
  typography: ThemeTypography(
    displayFamily: 'DancingScript',
    bodyFamily: 'Nunito',
    displayScale: 1.2,
  ),
  components: ThemeComponentStyle(
    buttonRadius: 26,
    cardRadius: 24,
    navigation: NavigationStyle.tinted,
  ),
  decoration: ThemeDecoration(
    kind: DecorationKind.petals,
    density: 1.0,
    opacity: 0.22,
  ),
  animation: ThemeAnimation(
    kind: AnimationKind.fall,
    period: Duration(seconds: 28),
  ),
  accentPresets: [
    AccentPreset(
      key: 'rose',
      label: 'Rose',
      primary: Color(0xFFB83B5E),
      darkPrimary: Color(0xFFF08FAE),
    ),
    AccentPreset(
      key: 'plum',
      label: 'Plum',
      primary: Color(0xFF8E3B6B),
      darkPrimary: Color(0xFFE3A1C8),
    ),
    AccentPreset(
      key: 'coral',
      label: 'Coral',
      primary: Color(0xFFA8432F),
      darkPrimary: Color(0xFFF2A28F),
    ),
  ],
  backgroundPresets: [
    BackgroundPreset(
      key: 'blossom',
      label: 'Blossom',
      background: Color(0xFFFFF5F7),
      surface: Colors.white,
    ),
    BackgroundPreset(
      key: 'cream',
      label: 'Cream',
      background: Color(0xFFFFF9F2),
      surface: Colors.white,
      darkBackground: Color(0xFF1F1915),
      darkSurface: Color(0xFF2B231D),
    ),
    BackgroundPreset(
      key: 'mist',
      label: 'Mist',
      background: Color(0xFFF7F5FA),
      surface: Colors.white,
      darkBackground: Color(0xFF19171E),
      darkSurface: Color(0xFF25222C),
    ),
  ],
  fontPresets: [
    FontPreset(
      key: 'romantic',
      label: 'Romantic',
      displayFamily: 'DancingScript',
      bodyFamily: 'Nunito',
    ),
    FontPreset(
      key: 'elegant',
      label: 'Elegant',
      displayFamily: 'PlayfairDisplay',
      bodyFamily: 'Nunito',
    ),
    FontPreset(
      key: 'simple',
      label: 'Simple',
      displayFamily: 'Nunito',
      bodyFamily: 'Nunito',
    ),
  ],
  photoBoothTemplates: {
    'romantic_frame',
    'polaroid',
    'classic_2',
    'vertical_strip',
  },
);
