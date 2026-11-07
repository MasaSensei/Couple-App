import 'package:flutter/material.dart';

import '../theme_definition.dart';

/// Dark navy with a few faint, glowing stars. Dark in every mode.
const _midnight = ThemePalette(
  brightness: Brightness.dark,
  primary: Color(0xFF8FB0FF),
  onPrimary: Color(0xFF0B1026),
  secondary: Color(0xFF2A335E),
  accent: Color(0xFFC9B6FF),
  background: Color(0xFF0B1026),
  surface: Color(0xFF151B38),
  textPrimary: Color(0xFFEEF1FF),
  textSecondary: Color(0xFFA8B0D6),
  border: Color(0xFF2A3260),
);

const midnightTheme = ThemeDefinition(
  key: 'midnight',
  name: 'Midnight',
  tagline: 'Deep navy, quiet stars and a soft glow.',
  version: 1,
  light: _midnight,
  dark: _midnight,
  typography: ThemeTypography(
    displayFamily: 'PlayfairDisplay',
    bodyFamily: 'Nunito',
  ),
  components: ThemeComponentStyle(
    buttonRadius: 14,
    cardRadius: 16,
    navigation: NavigationStyle.flat,
  ),
  decoration: ThemeDecoration(
    kind: DecorationKind.stars,
    density: 0.6,
    opacity: 0.55,
  ),
  animation: ThemeAnimation(
    kind: AnimationKind.twinkle,
    period: Duration(seconds: 6),
  ),
  accentPresets: [
    AccentPreset(
      key: 'moonlight',
      label: 'Moonlight',
      primary: Color(0xFF8FB0FF),
      onPrimary: Color(0xFF0B1026),
    ),
    AccentPreset(
      key: 'lavender',
      label: 'Lavender glow',
      primary: Color(0xFFC9B6FF),
      onPrimary: Color(0xFF1A1033),
    ),
    AccentPreset(
      key: 'aurora',
      label: 'Aurora',
      primary: Color(0xFF7FE3C4),
      onPrimary: Color(0xFF07261D),
    ),
  ],
  backgroundPresets: [
    BackgroundPreset(
      key: 'navy',
      label: 'Navy',
      background: Color(0xFF0B1026),
      surface: Color(0xFF151B38),
    ),
    BackgroundPreset(
      key: 'ink',
      label: 'Ink',
      background: Color(0xFF080A14),
      surface: Color(0xFF12152A),
    ),
  ],
  fontPresets: [
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
  photoBoothTemplates: {'classic_2', 'classic_4', 'vertical_strip'},
);
