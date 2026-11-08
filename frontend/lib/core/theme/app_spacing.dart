/// 4pt spacing grid. Global on purpose: themes change character, not rhythm.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double smd = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal page gutter on phones.
  static const double gutter = 20;

  /// Content never grows wider than this (tablets, landscape).
  static const double maxContentWidth = 640;

  /// Minimum touch target (Material / WCAG 2.5.8).
  static const double minTouch = 48;
}
