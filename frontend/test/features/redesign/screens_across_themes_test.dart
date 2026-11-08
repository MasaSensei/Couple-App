import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/theme_customization.dart';
import 'package:frontend/core/theme/theme_registry.dart';
import 'package:frontend/features/home/presentation/date_list_screen.dart';
import 'package:frontend/features/home/presentation/home_screen.dart';
import 'package:frontend/features/home/providers/couple_state.dart';
import 'package:frontend/features/memories/presentation/screens/memory_list_screen.dart';
import 'package:frontend/features/profile/presentation/me_screen.dart';

import '../../support/screen_harness.dart';

/// Step 6: every redesigned main screen, in every theme and mode, at phone
/// size and with large text, lays out without overflow or exceptions.
void main() {
  final screens = <String, Widget Function()>{
    'home': () => const HomeScreen(),
    'dates': () => const DateListScreen(),
    'memories': () => const MemoryListScreen(),
    'me': () => const MeScreen(),
  };

  Future<void> scrollThrough(WidgetTester tester) async {
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isEmpty) return;
    for (var i = 0; i < 6; i++) {
      await tester.drag(
        scrollables.first,
        const Offset(0, -400),
        warnIfMissed: false,
      );
      await tester.pump();
    }
  }

  for (final theme in ThemeRegistry.all) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${theme.key} ${brightness.name}: main screens lay out cleanly',
        (tester) async {
          for (final (size, scale) in const [
            (Size(390, 844), 1.0),
            (Size(360, 740), 1.3),
          ]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            for (final MapEntry(key: name, value: build) in screens.entries) {
              await pumpScreen(
                tester,
                build(),
                theme: theme,
                brightness: brightness,
                textScale: scale,
              );
              await scrollThrough(tester);
              expect(
                tester.takeException(),
                isNull,
                reason:
                    '$name in ${theme.key} ${brightness.name} at $size x$scale',
              );
            }
          }
          tester.view.reset();
        },
      );
    }
  }

  testWidgets('every Couple Space and Memory style renders', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final space in CoupleSpaceStyle.values) {
      await pumpScreen(
        tester,
        const HomeScreen(),
        theme: ThemeRegistry.defaultTheme,
        customization: ThemeCustomization(coupleSpaceStyle: space),
        textScale: 1.3,
      );
      await scrollThrough(tester);
      expect(tester.takeException(), isNull, reason: space.name);
    }
    for (final memory in MemoryStyle.values) {
      await pumpScreen(
        tester,
        const MemoryListScreen(),
        theme: ThemeRegistry.byKey('vintage_film'),
        customization: ThemeCustomization(memoryStyle: memory),
        textScale: 1.3,
      );
      await scrollThrough(tester);
      expect(tester.takeException(), isNull, reason: memory.name);
    }
  });

  testWidgets('home shows the couple, the next date and real relative dates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpScreen(
      tester,
      const HomeScreen(),
      theme: ThemeRegistry.defaultTheme,
    );

    expect(find.text('Raka & Nadia'), findsOneWidget);
    expect(find.textContaining('Together'), findsOneWidget);
    expect(find.textContaining('since 22 Sep 2025'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Next date: Dinner at the little corner')),
      findsOneWidget,
    );
    expect(find.text('NEXT DATE'), findsOneWidget);
    expect(find.text('FROM OUR JOURNAL'), findsOneWidget);
    // Activity is built from loaded data; the partner's plan is attributed to her.
    expect(
      find.textContaining('Nadia planned', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets(
    'without an anniversary, home says when the space started (no invented number)',
    (tester) async {
      await pumpScreen(
        tester,
        const HomeScreen(),
        theme: ThemeRegistry.defaultTheme,
        couple: CoupleState(
          status: CoupleStatus.loaded,
          couple: sampleCouple.copyWithoutAnniversary(),
        ),
      );

      expect(find.textContaining('Together'), findsNothing);
      expect(find.text('Our space since March 2025'), findsOneWidget);
    },
  );

  testWidgets(
    'home without a couple shows onboarding and hides nothing important',
    (tester) async {
      await pumpScreen(
        tester,
        const HomeScreen(),
        theme: ThemeRegistry.defaultTheme,
        couple: const CoupleState(status: CoupleStatus.empty),
      );

      expect(find.text('Create our space'), findsOneWidget);
      expect(find.text('I have an invitation'), findsOneWidget);
    },
  );

  testWidgets('date planner separates upcoming and past with status chips', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpScreen(
      tester,
      const DateListScreen(),
      theme: ThemeRegistry.defaultTheme,
    );

    expect(find.text('Upcoming · 2'), findsOneWidget);
    expect(find.text('Past · 2'), findsOneWidget);
    expect(find.text('Planned'), findsNWidgets(2));

    await tester.tap(find.text('Past · 2'));
    await tester.pump();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('me groups settings and logout asks first', (tester) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpScreen(
      tester,
      const MeScreen(),
      theme: ThemeRegistry.defaultTheme,
    );

    for (final group in [
      'OUR COUPLE',
      'APPEARANCE',
      'PLAN & STORAGE',
      'PRIVACY & SECURITY',
      'SUPPORT',
    ]) {
      expect(find.text(group), findsOneWidget, reason: group);
    }
    expect(find.text('22 Sep 2025'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsNothing);
  });
}
