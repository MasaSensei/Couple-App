import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/theme_customization.dart';
import 'package:frontend/core/theme/theme_definition.dart';
import 'package:frontend/core/theme/theme_registry.dart';
import 'package:frontend/core/widgets/app_widgets.dart';

import 'component_gallery.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Widget themed(
  Widget child, {
  ThemeDefinition? theme,
  Brightness brightness = Brightness.light,
  ThemeCustomization customization = ThemeCustomization.defaults,
  double textScale = 1,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    theme: AppTheme.build(
      theme ?? ThemeRegistry.defaultTheme,
      brightness,
      customization: customization,
    ),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  group('semantic colours stay readable on every theme and mode', () {
    for (final theme in ThemeRegistry.all) {
      for (final brightness in Brightness.values) {
        test('${theme.key} ${brightness.name}', () {
          final t = AppTheme.resolveTokens(
            theme,
            theme.palette(brightness).brightness,
          );

          for (final tone in StatusTone.values) {
            final ratio = contrast(
              t.onToneContainer(tone),
              t.toneContainer(tone),
            );
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason: '$tone chip = ${ratio.toStringAsFixed(2)}',
            );
          }

          for (final (name, fg, bg, min) in [
            ('caption/surfaceMuted', t.textSecondary, t.surfaceMuted, 4.5),
            ('ink/paper (polaroid caption)', t.onPaper, t.paper, 4.5),
            // Handwriting is large (≥ 18px): WCAG large-text minimum.
            ('handwriting/background', t.handwriting.color!, t.background, 3.0),
            ('primary link/background', t.primary, t.background, 3.0),
          ]) {
            expect(
              contrast(fg, bg),
              greaterThanOrEqualTo(min),
              reason: '$name = ${contrast(fg, bg).toStringAsFixed(2)}',
            );
          }
        });
      }
    }
  });

  test('every theme resolves the new tokens and they interpolate', () {
    for (final theme in ThemeRegistry.all) {
      final t = AppTheme.resolveTokens(theme, Brightness.light);
      expect(t.ornament, theme.ornament, reason: theme.key);
      expect(t.handwriting.fontFamily, theme.typography.handwritingFamily);
      expect(t.elevation(0), isEmpty);
      expect(t.elevation(2), isNotEmpty);
    }

    final a = AppTheme.resolveTokens(
      ThemeRegistry.defaultTheme,
      Brightness.light,
    );
    final b = AppTheme.resolveTokens(
      ThemeRegistry.byKey('midnight'),
      Brightness.dark,
    );
    final mid = a.lerp(b, 0.5);
    expect(mid.surfaceMuted, Color.lerp(a.surfaceMuted, b.surfaceMuted, 0.5));
    expect(mid.photoRadius, (a.photoRadius + b.photoRadius) / 2);
  });

  test('themes have distinct ornaments', () {
    final kinds = ThemeRegistry.all.map((t) => t.ornament).toSet();
    expect(kinds.length, ThemeRegistry.all.length);
  });

  group('component gallery lays out on every theme without overflow', () {
    for (final theme in ThemeRegistry.all) {
      for (final brightness in Brightness.values) {
        testWidgets('${theme.key} ${brightness.name}', (tester) async {
          for (final (size, scale) in const [
            (Size(360, 800), 1.0),
            (Size(320, 640), 1.3),
            (Size(900, 700), 1.0),
          ]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(
              themed(
                const ComponentGallery(),
                theme: theme,
                brightness: brightness,
                textScale: scale,
              ),
            );
            // Scroll through the whole gallery so every item is laid out.
            final list = find.byType(Scrollable).first;
            for (var i = 0; i < 8; i++) {
              await tester.drag(list, const Offset(0, -500));
              await tester.pump();
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '${theme.key} ${brightness.name} $size x$scale',
            );
          }
          tester.view.reset();
        });
      }
    }
  });

  testWidgets(
    'ornaments follow the decorations toggle and stay out of semantics',
    (tester) async {
      Finder ornaments() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is OrnamentPainter,
      );

      await tester.pumpWidget(
        themed(const JournalCard(ornament: true, child: Text('Memory'))),
      );
      expect(ornaments(), findsOneWidget);
      expect(
        find.ancestor(of: ornaments(), matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );

      await tester.pumpWidget(
        themed(
          const JournalCard(ornament: true, child: Text('Memory')),
          customization: const ThemeCustomization(decorations: false),
        ),
      );
      await tester.pumpAndSettle(); // the theme change animates in
      expect(ornaments(), findsNothing);
    },
  );

  testWidgets('context.motion honours the platform and the user preference', (
    tester,
  ) async {
    late AppMotion motion;
    final probe = Builder(
      builder: (context) {
        motion = context.motion;
        return const SizedBox();
      },
    );

    await tester.pumpWidget(themed(probe));
    expect(motion.reduced, isFalse);
    expect(motion.base, AppMotion.baseDuration);

    await tester.pumpWidget(themed(probe, disableAnimations: true));
    await tester.pumpAndSettle();
    expect(motion.reduced, isTrue);
    expect(motion.base, Duration.zero);
    expect(motion.pressScale, 1.0);

    final base = AppTheme.build(ThemeRegistry.defaultTheme, Brightness.light);
    final reduced = base.copyWith(
      extensions: [
        base.extension<AppThemeTokens>()!.copyWith(reduceMotion: true),
      ],
    );
    await tester.pumpWidget(MaterialApp(theme: reduced, home: probe));
    await tester.pumpAndSettle();
    expect(motion.reduced, isTrue);
  });

  testWidgets('loading button is disabled and announces its label', (
    tester,
  ) async {
    var taps = 0;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      themed(
        AppButton(label: 'Save', isLoading: true, onPressed: () => taps++),
      ),
    );

    await tester.tap(find.byType(AppButton));
    expect(taps, 0);
    expect(find.bySemanticsLabel('Save, loading'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('error state retries', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      themed(AppStateView.error(message: 'Offline', onAction: () => retries++)),
    );

    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('confirm sheet resolves true only on confirm', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(
      themed(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showConfirmSheet(
                context,
                title: 'Log out?',
                message: 'You can log back in any time.',
                confirmLabel: 'Log out',
                destructive: true,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Log out'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // tap the scrim
    await tester.pumpAndSettle();

    expect(results, [true, false, false]);
  });

  test('polaroid tilt is deterministic and small', () {
    for (var seed = 0; seed < 20; seed++) {
      final a = PolaroidFrame.tiltFor(seed);
      expect(a, PolaroidFrame.tiltFor(seed));
      expect(a.abs(), lessThanOrEqualTo(0.03));
    }
  });

  group('formatters', () {
    final now = DateTime(2026, 11, 8, 21);

    test('dates', () {
      final d = DateTime(2026, 11, 14, 19, 5);
      expect(AppFormatters.dayMonthYear(d), '14 Nov 2026');
      expect(AppFormatters.monthYear(d), 'November 2026');
      expect(AppFormatters.weekdayTime(d), 'Sat 19:05');
      expect(AppFormatters.full(d), 'Sat, 14 Nov 2026 · 19:05');
    });

    test('relative days use calendar days, not 24h blocks', () {
      expect(
        AppFormatters.relativeDays(DateTime(2026, 11, 8, 1), now: now),
        'Today',
      );
      expect(
        AppFormatters.relativeDays(DateTime(2026, 11, 9, 0, 30), now: now),
        'Tomorrow',
      );
      expect(
        AppFormatters.relativeDays(DateTime(2026, 11, 14), now: now),
        'in 6 days',
      );
      expect(
        AppFormatters.relativeDays(DateTime(2026, 11, 7, 23), now: now),
        'Yesterday',
      );
      expect(
        AppFormatters.relativeDays(DateTime(2026, 11, 1), now: now),
        '7 days ago',
      );
    });

    test('activity times', () {
      expect(
        AppFormatters.sinceShort(
          now.subtract(const Duration(seconds: 20)),
          now: now,
        ),
        'Just now',
      );
      expect(
        AppFormatters.sinceShort(
          now.subtract(const Duration(minutes: 5)),
          now: now,
        ),
        '5 min ago',
      );
      expect(
        AppFormatters.sinceShort(
          now.subtract(const Duration(hours: 2)),
          now: now,
        ),
        '2 h ago',
      );
      expect(
        AppFormatters.sinceShort(DateTime(2026, 11, 7, 22), now: now),
        'Yesterday',
      );
      expect(
        AppFormatters.sinceShort(DateTime(2026, 10, 2), now: now),
        '2 Oct',
      );
      expect(
        AppFormatters.sinceShort(DateTime(2025, 10, 2), now: now),
        '2 Oct 2025',
      );
    });
  });
}
