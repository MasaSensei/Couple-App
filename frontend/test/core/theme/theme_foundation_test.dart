import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_text_styles.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/app_theme_tokens.dart';
import 'package:frontend/core/theme/theme_customization.dart';
import 'package:frontend/core/theme/theme_registry.dart';

void main() {
  group('default theme keeps the pre-Phase 7 look', () {
    final tokens = AppTheme.resolveTokens(
      ThemeRegistry.defaultTheme,
      Brightness.light,
    );

    test('colors are the original constants', () {
      expect(tokens.primary, AppColors.primary);
      expect(tokens.secondary, AppColors.secondary);
      expect(tokens.background, AppColors.background);
      expect(tokens.surface, AppColors.surface);
      expect(tokens.textPrimary, AppColors.textPrimary);
      expect(tokens.textSecondary, AppColors.textSecondary);
      expect(tokens.border, AppColors.border);
      expect(tokens.error, AppColors.error);
    });

    test('text styles match the original sizes, weights and colors', () {
      for (final (actual, original) in [
        (tokens.display, AppTextStyles.display),
        (tokens.title, AppTextStyles.title),
        (tokens.subtitle, AppTextStyles.subtitle),
        (tokens.body, AppTextStyles.body),
        (tokens.button, AppTextStyles.button),
      ]) {
        expect(actual.fontSize, original.fontSize);
        expect(actual.fontWeight, original.fontWeight);
        expect(actual.color, original.color);
        expect(actual.fontFamily, isNull);
      }
    });

    test(
      'AppTheme.light carries the tokens and the original scaffold color',
      () {
        final theme = AppTheme.light();

        expect(theme.extension<AppThemeTokens>()?.themeKey, 'classic_rose');
        expect(theme.scaffoldBackgroundColor, AppColors.background);
      },
    );
  });

  test('unknown theme keys fall back to the default theme', () {
    expect(
      ThemeRegistry.byKey('from-a-newer-server').key,
      ThemeRegistry.defaultKey,
    );
    expect(ThemeRegistry.byKey(null).key, ThemeRegistry.defaultKey);
  });

  test('unknown customization presets are ignored, never break the theme', () {
    final tokens = AppTheme.resolveTokens(
      ThemeRegistry.defaultTheme,
      Brightness.light,
      customization: const ThemeCustomization(
        accent: 'neon',
        background: 'nope',
        font: 'comic',
      ),
    );

    expect(tokens.primary, AppColors.primary);
    expect(tokens.background, AppColors.background);
  });

  test('customization JSON round-trips and omits defaults', () {
    const custom = ThemeCustomization(
      accent: 'blush',
      decorations: false,
      coupleSpaceStyle: CoupleSpaceStyle.cozy,
      memoryStyle: MemoryStyle.polaroid,
    );

    expect(ThemeCustomization.fromJson(custom.toJson()), custom);
    expect(ThemeCustomization.defaults.toJson(), isEmpty);
    expect(
      ThemeCustomization.fromJson({'memory_style': 'unknown'}).memoryStyle,
      MemoryStyle.soft,
    );
  });

  test('tokens interpolate so theme switches animate', () {
    final a = AppThemeTokens.fallback;
    final b = AppTheme.resolveTokens(
      ThemeRegistry.defaultTheme,
      Brightness.light,
      customization: const ThemeCustomization(decorations: false),
    );
    final dark = a.lerp(b, 0.5);

    expect(dark.primary, Color.lerp(a.primary, b.primary, 0.5));
    expect(a.lerp(null, 0.3), same(a));
  });

  testWidgets('context.tokens falls back outside the app theme', (
    tester,
  ) async {
    late AppThemeTokens read;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          read = context.tokens;
          return const SizedBox();
        },
      ),
    );

    expect(read.themeKey, 'classic_rose');
  });
}
