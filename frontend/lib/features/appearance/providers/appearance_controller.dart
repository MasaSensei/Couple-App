import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/error/api_exception.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/app_theme_tokens.dart';
import 'package:frontend/core/theme/theme_customization.dart';
import 'package:frontend/core/theme/theme_registry.dart';
import 'package:frontend/features/auth/providers/auth_providers.dart';
import 'package:frontend/features/auth/providers/auth_state.dart';

import '../data/appearance_local_store.dart';
import '../data/appearance_models.dart';
import '../data/appearance_repository.dart';

/// Overridden in `main()` with the real SharedPreferences instance, so the
/// cached theme is available synchronously on the very first frame.
final appearanceLocalStoreProvider = Provider<AppearanceLocalStore>(
  (ref) => throw UnimplementedError(
    'appearanceLocalStoreProvider must be overridden in main()',
  ),
);

final appearanceRepositoryProvider = Provider<AppearanceRepository>(
  (ref) => AppearanceRepository(ApiClient()),
);

final appearanceControllerProvider =
    NotifierProvider<AppearanceController, AppearanceState>(
      AppearanceController.new,
    );

/// ThemeData for the active couple theme, per brightness.
final appThemeDataProvider = Provider.family<ThemeData, Brightness>((
  ref,
  brightness,
) {
  final state = ref.watch(appearanceControllerProvider);
  final theme = AppTheme.build(
    ThemeRegistry.byKey(state.settings.themeKey),
    brightness,
    customization: state.settings.customization,
  );

  if (!state.reduceMotion) return theme;

  // Personal "reduce motion" switches off theme animation on this device only.
  final tokens = theme.extension<AppThemeTokens>()!.copyWith(
    animationsEnabled: false,
  );
  return theme.copyWith(extensions: [tokens]);
});

/// `locked`: the theme is part of a paid plan the couple does not have.
enum ApplyOutcome { applied, conflict, locked, failed }

@immutable
class AppearanceState {
  const AppearanceState({
    required this.settings,
    this.catalog,
    this.themeMode = ThemeMode.system,
    this.reduceMotion = false,
    this.saving = false,
    this.partnerChanged = false,
  });

  /// The couple's shared settings as last confirmed by the server (or cache).
  final CoupleThemeSettings settings;
  final AppearanceCatalog? catalog;

  /// Personal, device-local preferences (never sent to the server).
  final ThemeMode themeMode;
  final bool reduceMotion;

  final bool saving;

  /// The partner changed the shared theme since this user last saw it.
  final bool partnerChanged;

  AppearanceState copyWith({
    CoupleThemeSettings? settings,
    AppearanceCatalog? catalog,
    ThemeMode? themeMode,
    bool? reduceMotion,
    bool? saving,
    bool? partnerChanged,
  }) => AppearanceState(
    settings: settings ?? this.settings,
    catalog: catalog ?? this.catalog,
    themeMode: themeMode ?? this.themeMode,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    saving: saving ?? this.saving,
    partnerChanged: partnerChanged ?? this.partnerChanged,
  );
}

/// Owns the shared couple theme and the personal preferences.
///
/// Writes are *confirmed, not optimistic*: the active theme changes only
/// after the server accepts it, so a failed request never leaves this device
/// showing something the partner does not see. On a version conflict the
/// partner's newer choice is adopted and the user is told.
class AppearanceController extends Notifier<AppearanceState> {
  AppearanceLocalStore get _store => ref.read(appearanceLocalStoreProvider);
  AppearanceRepository get _repository =>
      ref.read(appearanceRepositoryProvider);

  @override
  AppearanceState build() {
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated &&
          previous?.status != AuthStatus.authenticated) {
        refresh();
      } else if (next.status == AuthStatus.unauthenticated &&
          previous?.status == AuthStatus.authenticated) {
        _forgetCouple();
      }
    });

    final store = ref.watch(appearanceLocalStoreProvider);

    return AppearanceState(
      settings: store.readCoupleTheme() ?? CoupleThemeSettings.initial,
      catalog: store.readCatalog(),
      themeMode: store.readThemeMode(),
      reduceMotion: store.readReduceMotion(),
    );
  }

  int? get _me => ref.read(authNotifierProvider).user?.id;

  /// Pulls the shared theme and catalog. Network errors keep the local copy.
  Future<bool> refresh() async {
    try {
      final results = await Future.wait([
        _repository.getCoupleTheme(),
        _repository.getCatalog(),
      ]);
      final remote = results[0] as CoupleThemeSettings;
      final catalog = results[1] as AppearanceCatalog;
      final seen = _store.readSeenVersion();

      await _store.writeCatalog(catalog);
      await _adopt(remote);
      state = state.copyWith(
        catalog: catalog,
        // A fresh device (seen 0) adopts silently; later partner edits are announced.
        partnerChanged:
            seen > 0 &&
            remote.version > seen &&
            remote.updatedBy != null &&
            remote.updatedBy != _me,
      );
      if (seen == 0) await _store.writeSeenVersion(remote.version);

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<ApplyOutcome> apply(
    String themeKey,
    ThemeCustomization customization,
  ) => _write(
    () => _repository.updateCoupleTheme(
      themeKey: themeKey,
      customization: customization,
      basedOnVersion: state.settings.version,
    ),
  );

  Future<ApplyOutcome> resetCustomization() => _write(
    () =>
        _repository.resetCustomization(basedOnVersion: state.settings.version),
  );

  void acknowledgePartnerChange() {
    _store.writeSeenVersion(state.settings.version);
    state = state.copyWith(partnerChanged: false);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _store.writeThemeMode(mode);
  }

  Future<void> setReduceMotion(bool value) async {
    state = state.copyWith(reduceMotion: value);
    await _store.writeReduceMotion(value);
  }

  Future<ApplyOutcome> _write(
    Future<CoupleThemeSettings> Function() request,
  ) async {
    if (state.saving) return ApplyOutcome.failed;
    state = state.copyWith(saving: true);

    try {
      final saved = await request();
      await _adopt(saved);
      await _store.writeSeenVersion(saved.version);
      state = state.copyWith(saving: false, partnerChanged: false);

      return ApplyOutcome.applied;
    } on ThemeConflictException catch (conflict) {
      await _adopt(conflict.current);
      state = state.copyWith(saving: false, partnerChanged: true);

      return ApplyOutcome.conflict;
    } on ApiException catch (error) {
      // Server-side entitlement check (premium theme without a paid plan).
      state = state.copyWith(saving: false);
      final code = error.data is Map ? (error.data as Map)['code'] : null;

      return error.statusCode == 403 && code == 'entitlement_required'
          ? ApplyOutcome.locked
          : ApplyOutcome.failed;
    } catch (_) {
      // Local settings untouched.
      state = state.copyWith(saving: false);

      return ApplyOutcome.failed;
    }
  }

  Future<void> _adopt(CoupleThemeSettings settings) async {
    await _store.writeCoupleTheme(settings);
    state = state.copyWith(settings: settings);
  }

  Future<void> _forgetCouple() async {
    await _store.clearCoupleData();
    state = state.copyWith(
      settings: CoupleThemeSettings.initial,
      partnerChanged: false,
    );
  }
}
