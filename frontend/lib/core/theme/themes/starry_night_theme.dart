import 'package:flutter/material.dart';

import '../theme_definition.dart';

/// Deep blue sky, gold stars and constellations. Dark in every mode.
const _starryNight = ThemePalette(
  brightness: Brightness.dark,
  primary: Color(0xFFF5C451),
  onPrimary: Color(0xFF1A1400),
  secondary: Color(0xFF24366B),
  accent: Color(0xFF6FA8FF),
  background: Color(0xFF0E1A3A),
  surface: Color(0xFF16244B),
  textPrimary: Color(0xFFF2F5FF),
  textSecondary: Color(0xFFB3C0E3),
  border: Color(0xFF2B3C70),
);

const starryNightTheme = ThemeDefinition(
  key: 'starry_night',
  name: 'Starry Night',
  tagline: 'Golden stars and constellations across a deep blue sky.',
  version: 1,
  light: _starryNight,
  dark: _starryNight,
  typography: ThemeTypography(
    displayFamily: 'PlayfairDisplay',
    bodyFamily: 'Quicksand',
    displayLetterSpacing: 0.4,
  ),
  components: ThemeComponentStyle(
    buttonRadius: 24,
    cardRadius: 20,
    navigation: NavigationStyle.tinted,
  ),
  ornament: OrnamentKind.goldStar,
  decoration: ThemeDecoration(
    kind: DecorationKind.constellations,
    density: 1.0,
    opacity: 0.60,
  ),
  animation: ThemeAnimation(
    kind: AnimationKind.twinkle,
    period: Duration(seconds: 5),
  ),
  accentPresets: [
    AccentPreset(
      key: 'gold',
      label: 'Star gold',
      primary: Color(0xFFF5C451),
      onPrimary: Color(0xFF1A1400),
    ),
    AccentPreset(
      key: 'comet',
      label: 'Comet blue',
      primary: Color(0xFF8CC0FF),
      onPrimary: Color(0xFF071A33),
    ),
    AccentPreset(
      key: 'nebula',
      label: 'Nebula pink',
      primary: Color(0xFFFFA8D2),
      onPrimary: Color(0xFF33091F),
    ),
  ],
  backgroundPresets: [
    BackgroundPreset(
      key: 'sky',
      label: 'Night sky',
      background: Color(0xFF0E1A3A),
      surface: Color(0xFF16244B),
    ),
    BackgroundPreset(
      key: 'deep',
      label: 'Deep space',
      background: Color(0xFF070D22),
      surface: Color(0xFF111A38),
    ),
  ],
  fontPresets: [
    FontPreset(
      key: 'celestial',
      label: 'Celestial',
      displayFamily: 'PlayfairDisplay',
      bodyFamily: 'Quicksand',
    ),
    FontPreset(
      key: 'simple',
      label: 'Simple',
      displayFamily: 'Quicksand',
      bodyFamily: 'Quicksand',
    ),
  ],
  photoBoothTemplates: {'classic_2', 'classic_4', 'polaroid', 'vertical_strip'},
);
