import 'package:flutter/material.dart';

/// Brand palette ("paper, ink and rosewood"): the Classic Rose theme and the
/// fallback when no theme is in scope. Screens never read these directly;
/// they read `context.tokens`. See docs/design/design-system.md.
abstract final class AppColors {
  // Light
  static const Color primary = Color(0xFFB4475F); // Rosewood
  static const Color primaryDark = Color(0xFF953950);
  static const Color secondary = Color(0xFFF7DCE1); // Blush
  static const Color accent = Color(0xFFC9822F); // Marigold, decorative only

  static const Color background = Color(0xFFFCF7F4); // Paper
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF6EDE9);
  static const Color paper = Color(0xFFFFFDF9);

  static const Color textPrimary = Color(0xFF34262B); // Ink
  static const Color textSecondary = Color(0xFF75606A); // Ink soft

  static const Color border = Color(0xFFEBDCD6);

  static const Color success = Color(0xFF3F7D5C); // Sage
  static const Color warning = Color(0xFF9A5B12); // Amber
  static const Color error = Color(0xFFB3394A); // Berry
  static const Color info = Color(0xFF386A92); // Dusk

  // Dark
  static const Color primaryOnDark = Color(0xFFF2A0B2);
  static const Color onPrimaryDark = Color(0xFF3A121C);
  static const Color secondaryDark = Color(0xFF4A2A33);
  static const Color accentDark = Color(0xFFE7B36F);
  static const Color backgroundDark = Color(0xFF1C1417);
  static const Color surfaceDark = Color(0xFF281D21);
  static const Color surfaceMutedDark = Color(0xFF33262B);
  static const Color paperDark = Color(0xFFF3ECE6);
  static const Color textPrimaryDark = Color(0xFFF6EAEE);
  static const Color textSecondaryDark = Color(0xFFC9AEB7);
  static const Color borderDark = Color(0xFF44323A);
  static const Color successDark = Color(0xFF8CC7A5);
  static const Color warningDark = Color(0xFFE8B66B);
  static const Color errorDark = Color(0xFFF2A3AC);
  static const Color infoDark = Color(0xFF9CC3E4);
}
