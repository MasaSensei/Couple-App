import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme_tokens.dart';
import 'package:frontend/core/theme/theme_customization.dart';
import 'package:frontend/core/theme/theme_registry.dart';
import 'package:frontend/features/appearance/data/appearance_local_store.dart';
import 'package:frontend/features/appearance/data/appearance_models.dart';
import 'package:frontend/features/appearance/presentation/partner_theme_banner.dart';
import 'package:frontend/features/appearance/presentation/theme_detail_screen.dart';
import 'package:frontend/features/appearance/presentation/theme_gallery_screen.dart';
import 'package:frontend/features/appearance/providers/appearance_controller.dart';
import 'package:frontend/features/auth/providers/auth_providers.dart';
import 'package:frontend/features/auth/providers/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'appearance_fakes.dart';

/// A full catalog so the gallery shows every theme.
class FullCatalogRepository extends FakeAppearanceRepository {
  bool slow = false;

  @override
  Future<AppearanceCatalog> getCatalog() async {
    if (slow) await Future<void>.delayed(const Duration(seconds: 1));
    if (offline) throw Exception('offline');
    return AppearanceCatalog(
      themes: [
        for (final t in ThemeRegistry.all)
          CatalogItem(key: t.key, name: t.name, version: t.version),
      ],
      photoBoothTemplates: const [],
    );
  }
}

/// The server offers nothing beyond the default theme.
class DefaultOnlyRepository extends FakeAppearanceRepository {
  @override
  Future<AppearanceCatalog> getCatalog() async => const AppearanceCatalog(
    themes: [
      CatalogItem(key: 'classic_rose', name: 'Classic Rose', version: 1),
    ],
    photoBoothTemplates: [],
  );
}

Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  Widget home,
  FakeAppearanceRepository repo,
) async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      appearanceLocalStoreProvider.overrideWithValue(
        AppearanceLocalStore(prefs),
      ),
      appearanceRepositoryProvider.overrideWithValue(repo),
      authNotifierProvider.overrideWith(
        () => FakeAuthNotifier(AuthState.authenticated(fakeUser)),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeDataProvider(Brightness.light)),
          // Theme ornaments animate forever; tests run with platform "reduce motion".
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: home,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

String activeKey(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first))
        .extension<AppThemeTokens>()!
        .themeKey;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('gallery lists every theme and marks the active one', (
    tester,
  ) async {
    bigScreen(tester);
    await pumpApp(tester, const ThemeGalleryScreen(), FullCatalogRepository());

    for (final theme in ThemeRegistry.all) {
      expect(find.text(theme.name), findsOneWidget, reason: theme.key);
    }
    expect(
      find.bySemanticsLabel(RegExp('Classic Rose theme, active')),
      findsOneWidget,
    );
    expect(find.text('Only on this device'), findsOneWidget);
  });

  testWidgets('loading then error state when the catalog cannot be fetched', (
    tester,
  ) async {
    final repo = FullCatalogRepository()..offline = true;
    await pumpApp(tester, const ThemeGalleryScreen(), repo);

    expect(find.text("We couldn't load the themes"), findsOneWidget);
    expect(find.textContaining('current theme is unchanged'), findsOneWidget);

    repo.offline = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Sakura'), findsOneWidget);
  });

  testWidgets('empty state when the server offers no extra themes', (
    tester,
  ) async {
    bigScreen(tester);
    await pumpApp(tester, const ThemeGalleryScreen(), DefaultOnlyRepository());

    expect(find.text('Classic Rose'), findsOneWidget);
    expect(find.text('Sakura'), findsNothing);
    expect(find.text('No extra themes yet'), findsOneWidget);
  });

  testWidgets('previewing and customizing never changes the active theme', (
    tester,
  ) async {
    bigScreen(tester);
    final repo = FullCatalogRepository();
    await pumpApp(
      tester,
      ThemeDetailScreen(definition: ThemeRegistry.byKey('sakura')),
      repo,
    );

    await tester.tap(find.text('Plum'));
    await tester.tap(find.text('Polaroid'));
    await tester.pumpAndSettle();

    expect(activeKey(tester), 'classic_rose');
    expect(repo.writes, 0);
  });

  testWidgets('apply asks for confirmation, then shares the theme', (
    tester,
  ) async {
    bigScreen(tester);
    final repo = FullCatalogRepository();
    final container = await pumpApp(
      tester,
      ThemeDetailScreen(definition: ThemeRegistry.byKey('cottage')),
      repo,
    );

    await tester.tap(find.text('Terracotta'));
    await tester.tap(find.text('Apply theme'));
    await tester.pumpAndSettle();
    expect(find.text('Use Cottage?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.writes, 0);

    await tester.tap(find.text('Apply theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(repo.server.themeKey, 'cottage');
    expect(repo.server.customization.accent, 'terracotta');
    expect(
      container.read(appearanceControllerProvider).settings.themeKey,
      'cottage',
    );
  });

  testWidgets('a conflict tells the user what the partner chose', (
    tester,
  ) async {
    bigScreen(tester);
    final repo = FullCatalogRepository();
    await pumpApp(
      tester,
      ThemeDetailScreen(definition: ThemeRegistry.byKey('cafe')),
      repo,
    );
    repo.partnerSaves('midnight');

    await tester.tap(find.text('Apply theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pump();

    expect(
      find.textContaining('Your partner just changed the theme to Midnight'),
      findsOneWidget,
    );
    expect(repo.server.themeKey, 'midnight');
  });

  testWidgets('reset is offered only for the active theme with changes', (
    tester,
  ) async {
    bigScreen(tester);
    final repo = FullCatalogRepository();
    final container = await pumpApp(
      tester,
      ThemeDetailScreen(definition: ThemeRegistry.byKey('sakura')),
      repo,
    );
    expect(find.text('Reset to theme defaults'), findsNothing);

    await container
        .read(appearanceControllerProvider.notifier)
        .apply('sakura', const ThemeCustomization(accent: 'coral'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reset to theme defaults'));
    await tester.pumpAndSettle();
    expect(repo.server.customization, ThemeCustomization.defaults);
    expect(repo.server.themeKey, 'sakura');
  });

  testWidgets(
    'partner banner appears after a partner change and can be dismissed',
    (tester) async {
      final repo = FullCatalogRepository();
      final container = await pumpApp(
        tester,
        const Scaffold(body: PartnerThemeBanner()),
        repo,
      );
      final controller = container.read(appearanceControllerProvider.notifier);
      await controller.apply('sakura', ThemeCustomization.defaults);

      repo.partnerSaves('vintage_film');
      await controller.refresh();
      await tester.pumpAndSettle();
      expect(
        find.text('Your partner changed your theme to Vintage Film.'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsNothing);
    },
  );
}
