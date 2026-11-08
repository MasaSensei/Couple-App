import 'package:flutter/material.dart';

import 'app_theme_tokens.dart';

/// Motion tokens. Every UI animation reads its duration from `context.motion`
/// so one switch (platform "reduce motion" or the user's own preference)
/// turns all non-essential motion off.
@immutable
class AppMotion {
  const AppMotion._(this.reduced);

  /// True when the platform or the user asked for less motion.
  final bool reduced;

  static const Duration fastDuration = Duration(milliseconds: 120);
  static const Duration baseDuration = Duration(milliseconds: 220);
  static const Duration slowDuration = Duration(milliseconds: 360);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubic;

  Duration get fast => reduced ? Duration.zero : fastDuration;
  Duration get base => reduced ? Duration.zero : baseDuration;
  Duration get slow => reduced ? Duration.zero : slowDuration;

  /// Stagger between list items entering; zero when reduced.
  Duration stagger(int index, {int max = 6}) => reduced
      ? Duration.zero
      : Duration(milliseconds: 40 * index.clamp(0, max));

  /// Scale applied while a card is pressed (1.0 = none).
  double get pressScale => reduced ? 1.0 : 0.98;
}

extension AppMotionContext on BuildContext {
  AppMotion get motion => AppMotion._(
    MediaQuery.maybeDisableAnimationsOf(this) == true || tokens.reduceMotion,
  );
}
