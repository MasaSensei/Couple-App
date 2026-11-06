import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/error/api_exception.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/theme_customization.dart';
import 'package:frontend/features/appearance/data/appearance_local_store.dart';
import 'package:frontend/features/appearance/data/appearance_models.dart';
import 'package:frontend/features/appearance/data/appearance_repository.dart';
import 'package:frontend/features/appearance/providers/appearance_controller.dart';
import 'package:frontend/features/auth/data/models/user_model.dart';
import 'package:frontend/features/auth/providers/auth_providers.dart';
import 'package:frontend/features/auth/providers/auth_notifier.dart';
import 'package:frontend/features/auth/providers/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const me = 1;
const partner = 2;

/// In-memory stand-in for the server, including the optimistic lock.
class FakeAppearanceRepository extends AppearanceRepository {
  FakeAppearanceRepository() : super(ApiClient());

  CoupleThemeSettings server = CoupleThemeSettings.initial;
  bool offline = false;
  int writes = 0;

  /// Simulates the partner saving between our read and our write.
  void partnerSaves(String themeKey) {
    server = CoupleThemeSettings(
      themeKey: themeKey,
      customization: ThemeCustomization.defaults,
      version: server.version + 1,
      updatedBy: partner,
    );
  }

  void _check() {
    if (offline) throw const ApiException(message: 'Unable to connect to the server.');
  }

  @override
  Future<AppearanceCatalog> getCatalog() async {
    _check();
    return const AppearanceCatalog(themes: [CatalogItem(key: 'sakura', name: 'Sakura', version: 1)], photoBoothTemplates: []);
  }

  @override
  Future<CoupleThemeSettings> getCoupleTheme() async {
    _check();
    return server;
  }

  @override
  Future<CoupleThemeSettings> updateCoupleTheme({
    required String themeKey,
    required ThemeCustomization customization,
    required int basedOnVersion,
  }) async {
    _check();
    if (basedOnVersion != server.version) throw ThemeConflictException(server);
    writes++;
    return server = CoupleThemeSettings(
      themeKey: themeKey,
      customization: customization,
      version: server.version + 1,
      updatedBy: me,
    );
  }

  @override
  Future<CoupleThemeSettings> resetCustomization({required int basedOnVersion}) =>
      updateCoupleTheme(themeKey: server.themeKey, customization: ThemeCustomization.defaults, basedOnVersion: basedOnVersion);
}

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(this.initial);

  final AuthState initial;

  @override
  AuthState build() => initial;

  void set(AuthState value) => state = value;
}

final fakeUser = UserModel.fromJson({'id': me, 'name': 'Me', 'email': 'me@example.test'});

Future<ProviderContainer> container(FakeAppearanceRepository repository, {AuthState? auth}) async {
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [
    appearanceLocalStoreProvider.overrideWithValue(AppearanceLocalStore(prefs)),
    appearanceRepositoryProvider.overrideWithValue(repository),
    authNotifierProvider.overrideWith(() => FakeAuthNotifier(auth ?? AuthState.authenticated(fakeUser))),
  ]);
  addTearDown(c.dispose);
  return c;
}

