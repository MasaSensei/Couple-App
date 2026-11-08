import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/app_theme_tokens.dart';
import 'package:frontend/core/theme/theme_customization.dart';
import 'package:frontend/core/theme/theme_decorations.dart';
import 'package:frontend/core/theme/theme_definition.dart';
import 'package:frontend/core/theme/theme_registry.dart';

/// WCAG 2.x contrast ratio.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

const bundledFonts = {
  'Nunito',
  'PlayfairDisplay',
  'CormorantGaramond',
  'Lora',
  'CourierPrime',
  'DancingScript',
  'Quicksand',
};

void main() {
  final newThemes = ThemeRegistry.all
      .where((t) => t.key != ThemeRegistry.defaultKey)
      .toList();

  test('the eight Phase 7 themes are registered with unique keys', () {
    expect(newThemes.map((t) => t.key), [
      'sakura',
      'winter_love',
      'midnight',
      'vintage_film',
      'imperial_winter',
      'cottage',
      'cafe',
      'starry_night',
    ]);
    expect(
      ThemeRegistry.all.map((t) => t.key).toSet().length,
      ThemeRegistry.all.length,
    );
  });

  test('themes differ in more than colour', () {
    final identities = newThemes
        .map(
          (t) =>
              '${t.typography.displayFamily}|${t.decoration.kind}|${t.components.cardRadius}|${t.components.navigation}',
        )
        .toSet();

    expect(identities.length, newThemes.length);
    for (final theme in newThemes) {
      expect(
        theme.decoration.kind,
        isNot(DecorationKind.none),
        reason: theme.key,
      );
      expect(
        theme.decoration.opacity,
        lessThanOrEqualTo(0.6),
        reason: '${theme.key}: ornaments must stay subtle',
      );
    }
  });

  test('presets have unique keys and only use bundled fonts', () {
    for (final theme in ThemeRegistry.all) {
      for (final keys in [
        theme.accentPresets.map((p) => p.key),
        theme.backgroundPresets.map((p) => p.key),
        theme.fontPresets.map((p) => p.key),
      ]) {
        expect(keys.toSet().length, keys.length, reason: theme.key);
      }

      final families = {
        theme.typography.displayFamily,
        theme.typography.bodyFamily,
        for (final f in theme.fontPresets) ...[f.displayFamily, f.bodyFamily],
      }.whereType<String>();
      expect(
        bundledFonts.containsAll(families),
        isTrue,
        reason: '${theme.key}: $families',
      );
    }
  });

  group('readability (WCAG AA 4.5:1) for every theme, mode and preset', () {
    // Includes Classic Rose: the brand palette passes AA since the redesign.
    for (final theme in ThemeRegistry.all) {
      for (final brightness in Brightness.values) {
        final variants = <String, ThemeCustomization>{
          'default': ThemeCustomization.defaults,
          for (final a in theme.accentPresets)
            'accent ${a.key}': ThemeCustomization(accent: a.key),
          for (final b in theme.backgroundPresets)
            'background ${b.key}': ThemeCustomization(background: b.key),
        };

        for (final MapEntry(key: label, value: customization)
            in variants.entries) {
          test('${theme.key} ${brightness.name} $label', () {
            final t = AppTheme.resolveTokens(
              theme,
              theme.palette(brightness).brightness,
              customization: customization,
            );

            for (final (name, fg, bg) in [
              ('text/background', t.textPrimary, t.background),
              ('text/surface', t.textPrimary, t.surface),
              ('secondary text/background', t.textSecondary, t.background),
              ('secondary text/surface', t.textSecondary, t.surface),
              ('button text/button', t.onPrimary, t.primary),
            ]) {
              expect(
                contrast(fg, bg),
                greaterThanOrEqualTo(4.5),
                reason: '$name = ${contrast(fg, bg).toStringAsFixed(2)}',
              );
            }
          });
        }
      }
    }
  });

  test('dark-only themes stay dark in light mode', () {
    for (final key in ['midnight', 'starry_night']) {
      final data = AppTheme.build(ThemeRegistry.byKey(key), Brightness.light);
      expect(data.brightness, Brightness.dark, reason: key);
    }
  });

  testWidgets(
    'every decoration paints at phone and tablet sizes without errors',
    (tester) async {
      for (final theme in ThemeRegistry.all) {
        for (final size in const [Size(360, 640), Size(1024, 768)]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.build(theme, Brightness.light),
              home: SizedBox.fromSize(
                size: size,
                child: const ThemedBackground(child: Text('Readable')),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: theme.key);
          expect(find.text('Readable'), findsOneWidget);
        }
      }
    },
  );

  testWidgets(
    'decorations are invisible to screen readers and never animate with reduce motion',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(
            ThemeRegistry.byKey('sakura'),
            Brightness.light,
          ),
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: ThemedBackground(child: Text('Hi')),
          ),
        ),
      );

      // No ticking animation: the tree settles immediately.
      await tester.pumpAndSettle();
      final painter =
          tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter
              as ThemeDecorationPainter;
      expect(painter.progress, isNull);
      expect(find.byType(ExcludeSemantics), findsWidgets);
    },
  );

  testWidgets('switching the decoration toggle off removes ornaments', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(
          ThemeRegistry.byKey('cottage'),
          Brightness.light,
          customization: const ThemeCustomization(decorations: false),
        ),
        home: const ThemedBackground(child: Text('Hi')),
      ),
    );

    expect(
      find
          .byType(CustomPaint)
          .evaluate()
          .where(
            (e) => (e.widget as CustomPaint).painter is ThemeDecorationPainter,
          ),
      isEmpty,
    );
    final tokens = Theme.of(tester.element(find.text('Hi')))
        .extension<AppThemeTokens>()!;
    expect(tokens.decorationsEnabled, isFalse);
  });
}
