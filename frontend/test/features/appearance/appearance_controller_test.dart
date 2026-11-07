import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme_tokens.dart';
import 'package:frontend/core/theme/theme_customization.dart';
import 'package:frontend/features/appearance/data/appearance_local_store.dart';
import 'package:frontend/features/appearance/providers/appearance_controller.dart';
import 'package:frontend/features/auth/providers/auth_providers.dart';
import 'package:frontend/features/auth/providers/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'appearance_fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('applying a theme saves it on the server and the device', () async {
    final repo = FakeAppearanceRepository();
    final c = await container(repo);
    final controller = c.read(appearanceControllerProvider.notifier);

    final outcome = await controller.apply(
      'sakura',
      const ThemeCustomization(accent: 'plum'),
    );

    expect(outcome, ApplyOutcome.applied);
    expect(c.read(appearanceControllerProvider).settings.themeKey, 'sakura');
    expect(repo.server.customization.accent, 'plum');
    expect(
      c
          .read(appThemeDataProvider(Brightness.light))
          .extension<AppThemeTokens>()!
          .themeKey,
      'sakura',
    );
  });

  test('the theme survives an app restart (read from the cache before the network)', () async {
    final repo = FakeAppearanceRepository();
    await (await container(repo))
        .read(appearanceControllerProvider.notifier)
        .apply('cottage', ThemeCustomization.defaults);

    // New process: server unreachable, cache still applies.
    final restarted = await container(
      FakeAppearanceRepository()..offline = true,
    );

    expect(
      restarted.read(appearanceControllerProvider).settings.themeKey,
      'cottage',
    );
    expect(
      restarted
          .read(appThemeDataProvider(Brightness.light))
          .extension<AppThemeTokens>()!
          .themeKey,
      'cottage',
    );
  });

  test('an API failure leaves the current theme untouched', () async {
    final repo = FakeAppearanceRepository();
    final c = await container(repo);
    final controller = c.read(appearanceControllerProvider.notifier);
    await controller.apply('midnight', ThemeCustomization.defaults);

    repo.offline = true;
    final outcome = await controller.apply('cafe', ThemeCustomization.defaults);

    expect(outcome, ApplyOutcome.failed);
    expect(c.read(appearanceControllerProvider).settings.themeKey, 'midnight');
    expect(c.read(appearanceControllerProvider).saving, isFalse);
    expect(await controller.refresh(), isFalse);
    expect(c.read(appearanceControllerProvider).settings.themeKey, 'midnight');
  });

  test('a concurrent change by the partner is adopted and announced, never overwritten', () async {
    final repo = FakeAppearanceRepository();
    final c = await container(repo);
    final controller = c.read(appearanceControllerProvider.notifier);
    await controller.refresh(); // both partners see version 0

    repo.partnerSaves('winter_love');
    final outcome = await controller.apply(
      'sakura',
      ThemeCustomization.defaults,
    );

    expect(outcome, ApplyOutcome.conflict);
    expect(repo.server.themeKey, 'winter_love');
    expect(repo.writes, 0);
    final state = c.read(appearanceControllerProvider);
    expect(state.settings.themeKey, 'winter_love');
    expect(state.partnerChanged, isTrue);

    // Re-applying on top of the partner's version works.
    expect(
      await controller.apply('sakura', ThemeCustomization.defaults),
      ApplyOutcome.applied,
    );
    expect(c.read(appearanceControllerProvider).partnerChanged, isFalse);
  });

  test(
    'the partner\'s change is picked up on refresh and announced once',
    () async {
      final repo = FakeAppearanceRepository();
      final c = await container(repo);
      final controller = c.read(appearanceControllerProvider.notifier);
      await controller.apply('sakura', ThemeCustomization.defaults);

      repo.partnerSaves('starry_night');
      await controller.refresh();

      expect(
        c.read(appearanceControllerProvider).settings.themeKey,
        'starry_night',
      );
      expect(c.read(appearanceControllerProvider).partnerChanged, isTrue);

      controller.acknowledgePartnerChange();
      await controller.refresh();
      expect(c.read(appearanceControllerProvider).partnerChanged, isFalse);
    },
  );

  test('a new device adopts the shared theme silently', () async {
    final repo = FakeAppearanceRepository()..partnerSaves('cafe');
    final c = await container(repo);

    await c.read(appearanceControllerProvider.notifier).refresh();

    expect(c.read(appearanceControllerProvider).settings.themeKey, 'cafe');
    expect(c.read(appearanceControllerProvider).partnerChanged, isFalse);
  });

  test('reset returns to the theme defaults and keeps the theme', () async {
    final repo = FakeAppearanceRepository();
    final c = await container(repo);
    final controller = c.read(appearanceControllerProvider.notifier);
    await controller.apply(
      'cottage',
      const ThemeCustomization(accent: 'terracotta', decorations: false),
    );

    expect(await controller.resetCustomization(), ApplyOutcome.applied);

    final settings = c.read(appearanceControllerProvider).settings;
    expect(settings.themeKey, 'cottage');
    expect(settings.customization, ThemeCustomization.defaults);
  });

  test(
    'personal preferences stay local and never touch the shared theme',
    () async {
      final repo = FakeAppearanceRepository();
      final c = await container(repo);
      final controller = c.read(appearanceControllerProvider.notifier);
      await controller.apply('sakura', ThemeCustomization.defaults);

      await controller.setThemeMode(ThemeMode.dark);
      await controller.setReduceMotion(true);

      expect(repo.writes, 1);
      final restarted = await container(repo);
      expect(
        restarted.read(appearanceControllerProvider).themeMode,
        ThemeMode.dark,
      );
      final tokens = restarted
          .read(appThemeDataProvider(Brightness.light))
          .extension<AppThemeTokens>()!;
      expect(
        tokens.animationsEnabled,
        isFalse,
        reason: 'reduce motion switches theme animation off on this device',
      );
    },
  );

  test('logging out clears the couple theme from the device', () async {
    final repo = FakeAppearanceRepository();
    final c = await container(repo);
    final controller = c.read(appearanceControllerProvider.notifier);
    await controller.apply('midnight', ThemeCustomization.defaults);

    (c.read(authNotifierProvider.notifier) as FakeAuthNotifier).set(
      const AuthState.unauthenticated(),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      c.read(appearanceControllerProvider).settings.themeKey,
      'classic_rose',
    );
    final prefs = await SharedPreferences.getInstance();
    expect(AppearanceLocalStore(prefs).readCoupleTheme(), isNull);
  });

  test('a corrupt cache falls back to the default theme', () async {
    SharedPreferences.setMockInitialValues({
      'appearance.couple_theme.v1': '{not json',
    });
    final c = await container(FakeAppearanceRepository()..offline = true);

    expect(
      c.read(appearanceControllerProvider).settings.themeKey,
      'classic_rose',
    );
  });
}
