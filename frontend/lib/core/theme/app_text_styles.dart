import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Brand type scale, used only for [AppThemeTokens.fallback] (widgets built
/// outside the app theme). Themes resolve their own styles in `AppTheme`.
abstract final class AppTextStyles {
  static const String displayFamily = 'PlayfairDisplay';
  static const String bodyFamily = 'Nunito';
  static const String handwritingFamily = 'DancingScript';

  static const TextStyle display = TextStyle(
    fontFamily: displayFamily,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.15,
  );

  static const TextStyle title = TextStyle(
    fontFamily: displayFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle body = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle label = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: AppColors.textSecondary,
    height: 1.2,
  );

  static const TextStyle handwriting = TextStyle(
    fontFamily: handwritingFamily,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: AppColors.primary,
    height: 1.2,
  );

  static const TextStyle button = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    height: 1.2,
  );
}
