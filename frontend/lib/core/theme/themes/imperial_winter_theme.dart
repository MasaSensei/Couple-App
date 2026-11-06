import 'package:flutter/material.dart';

import '../theme_definition.dart';

/// Refined winter elegance: royal violet, soft gold filigree, serif display.
const imperialWinterTheme = ThemeDefinition(
  key: 'imperial_winter',
  name: 'Imperial Winter',
  tagline: 'A winter palace: violet, gold filigree and graceful type.',
  version: 1,
  light: ThemePalette(
    brightness: Brightness.light,
    primary: Color(0xFF5B4B8A),
    onPrimary: Colors.white,
    secondary: Color(0xFFE6E1F2),
    accent: Color(0xFFB8A46A),
    background: Color(0xFFF7F6FB),
    surface: Colors.white,
    textPrimary: Color(0xFF24203A),
    textSecondary: Color(0xFF5D5778),
    border: Color(0xFFE3DEEF),
  ),
  dark: ThemePalette(
    brightness: Brightness.dark,
    primary: Color(0xFFB9A8E8),
    onPrimary: Color(0xFF221A3D),
    secondary: Color(0xFF332C4D),
    accent: Color(0xFFD8C489),
    background: Color(0xFF15131F),
    surface: Color(0xFF201D2E),
    textPrimary: Color(0xFFF0EDF8),
    textSecondary: Color(0xFFB6AFCB),
    border: Color(0xFF363149),
  ),
  typography: ThemeTypography(
    displayFamily: 'CormorantGaramond',
    bodyFamily: 'Lora',
    displayWeight: FontWeight.w600,
    displayLetterSpacing: 0.6,
    displayScale: 1.12,
  ),
  components: ThemeComponentStyle(buttonRadius: 12, cardRadius: 12, navigation: NavigationStyle.elevated),
  decoration: ThemeDecoration(kind: DecorationKind.ornaments, density: 0.8, opacity: 0.35),
  animation: ThemeAnimation(kind: AnimationKind.drift, period: Duration(seconds: 40)),
  accentPresets: [
    AccentPreset(key: 'royal', label: 'Royal violet', primary: Color(0xFF5B4B8A), darkPrimary: Color(0xFFB9A8E8)),
    AccentPreset(key: 'tsarina', label: 'Tsarina blue', primary: Color(0xFF2E4A7D), darkPrimary: Color(0xFFA5BCE8)),
    AccentPreset(key: 'garnet', label: 'Garnet', primary: Color(0xFF7D2E46), darkPrimary: Color(0xFFE8A5B9)),
  ],
  backgroundPresets: [
    BackgroundPreset(key: 'ice_lilac', label: 'Ice lilac', background: Color(0xFFF7F6FB), surface: Colors.white),
    BackgroundPreset(key: 'pearl', label: 'Pearl', background: Color(0xFFF8F6F1), surface: Color(0xFFFFFEFB),
        darkBackground: Color(0xFF17151A), darkSurface: Color(0xFF221F26)),
  ],
  fontPresets: [
    FontPreset(key: 'imperial', label: 'Imperial', displayFamily: 'CormorantGaramond', bodyFamily: 'Lora'),
    FontPreset(key: 'modern', label: 'Modern', displayFamily: 'PlayfairDisplay', bodyFamily: 'Nunito'),
  ],
  photoBoothTemplates: {'winter_frame', 'romantic_frame', 'classic_2', 'polaroid'},
);
