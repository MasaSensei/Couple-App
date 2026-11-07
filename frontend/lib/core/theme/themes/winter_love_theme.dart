import 'package:flutter/material.dart';

import '../theme_definition.dart';

/// White, icy blue and silver: crisp rounded type, floating snowflakes.
const winterLoveTheme = ThemeDefinition(
  key: 'winter_love',
  name: 'Winter Love',
  tagline: 'Icy blue and silver, light as fresh snow.',
  version: 1,
  light: ThemePalette(
    brightness: Brightness.light,
    primary: Color(0xFF2F6690),
    onPrimary: Colors.white,
    secondary: Color(0xFFCFE3F2),
    accent: Color(0xFF9DB4C8),
    background: Color(0xFFF4F8FC),
    surface: Colors.white,
    textPrimary: Color(0xFF1D2B3A),
    textSecondary: Color(0xFF4E6275),
    border: Color(0xFFD8E4EE),
  ),
  dark: ThemePalette(
    brightness: Brightness.dark,
    primary: Color(0xFF8EC3EA),
    onPrimary: Color(0xFF0B2236),
    secondary: Color(0xFF223A50),
    accent: Color(0xFFC4D3E0),
    background: Color(0xFF0F1822),
    surface: Color(0xFF172430),
    textPrimary: Color(0xFFE8F1F8),
    textSecondary: Color(0xFFA9BCCB),
    border: Color(0xFF2A3B4B),
  ),
  typography: ThemeTypography(
    displayFamily: 'Quicksand',
    bodyFamily: 'Quicksand',
    displayWeight: FontWeight.w600,
    displayLetterSpacing: 0.3,
  ),
  components: ThemeComponentStyle(
    buttonRadius: 16,
    cardRadius: 18,
    cardElevation: 1,
    cardBorder: false,
  ),
  decoration: ThemeDecoration(
    kind: DecorationKind.snowflakes,
    density: 1.0,
    opacity: 0.30,
  ),
  animation: ThemeAnimation(
    kind: AnimationKind.fall,
    period: Duration(seconds: 36),
  ),
  accentPresets: [
    AccentPreset(
      key: 'ice',
      label: 'Ice blue',
      primary: Color(0xFF2F6690),
      darkPrimary: Color(0xFF8EC3EA),
    ),
    AccentPreset(
      key: 'silver',
      label: 'Silver',
      primary: Color(0xFF4F5D6B),
      darkPrimary: Color(0xFFC4D3E0),
    ),
    AccentPreset(
      key: 'berry',
      label: 'Winter berry',
      primary: Color(0xFF9B2C47),
      darkPrimary: Color(0xFFF1A3B6),
    ),
  ],
  backgroundPresets: [
    BackgroundPreset(
      key: 'snow',
      label: 'Snow',
      background: Color(0xFFF4F8FC),
      surface: Colors.white,
    ),
    BackgroundPreset(
      key: 'frost',
      label: 'Frost',
      background: Color(0xFFEEF3F8),
      surface: Color(0xFFFCFDFF),
      darkBackground: Color(0xFF0C141D),
      darkSurface: Color(0xFF14202B),
    ),
  ],
  fontPresets: [
    FontPreset(
      key: 'crisp',
      label: 'Crisp',
      displayFamily: 'Quicksand',
      bodyFamily: 'Quicksand',
    ),
    FontPreset(
      key: 'elegant',
      label: 'Elegant',
      displayFamily: 'PlayfairDisplay',
      bodyFamily: 'Quicksand',
    ),
  ],
  photoBoothTemplates: {'winter_frame', 'classic_3', 'classic_4', 'polaroid'},
);
