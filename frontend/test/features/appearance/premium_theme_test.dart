import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/error/api_exception.dart';
import 'package:frontend/core/theme/theme_customization.dart';
import 'package:frontend/features/appearance/data/appearance_models.dart';
import 'package:frontend/features/appearance/providers/appearance_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'appearance_fakes.dart';

/// The server refuses premium themes outside the couple's plan (403).
class _PremiumLockedRepository extends FakeAppearanceRepository {
  @override
  Future<CoupleThemeSettings> updateCoupleTheme({
    required String themeKey,
    required ThemeCustomization customization,
    required int basedOnVersion,
  }) async =>
      throw const ApiException(
        message: 'This theme is part of a paid plan.',
        statusCode: 403,
        data: {'code': 'entitlement_required', 'entitlement': 'premium_themes'},
      );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a premium theme refused by the server is reported as locked and nothing changes', () async {
    final c = await container(_PremiumLockedRepository());

    final outcome = await c.read(appearanceControllerProvider.notifier).apply('cafe', ThemeCustomization.defaults);

    expect(outcome, ApplyOutcome.locked);
    expect(c.read(appearanceControllerProvider).settings.themeKey, CoupleThemeSettings.initial.themeKey);
    expect(c.read(appearanceControllerProvider).saving, isFalse);
  });

  test('catalog items carry the server locked flag', () {
    final item = CatalogItem.fromJson({'key': 'cafe', 'name': 'Café', 'version': 1, 'is_premium': true, 'locked': true});

    expect(item.locked, isTrue);
    expect(CatalogItem.fromJson(item.toJson()).locked, isTrue);
    expect(CatalogItem.fromJson({'key': 'sakura'}).locked, isFalse);
  });
}
