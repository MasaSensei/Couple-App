import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'appearance_models.dart';

/// Device-local appearance data. Nothing secret lives here (no keys, no
/// photos): the last known couple theme, so the app opens in the right theme
/// before the network answers, and the user's *personal* preferences, which
/// are never shared with the partner.
class AppearanceLocalStore {
  AppearanceLocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const _coupleTheme = 'appearance.couple_theme.v1';
  static const _catalog = 'appearance.catalog.v1';
  static const _seenVersion = 'appearance.seen_version.v1';
  static const _themeMode = 'appearance.theme_mode.v1';
  static const _reduceMotion = 'appearance.reduce_motion.v1';

  CoupleThemeSettings? readCoupleTheme() =>
      _decode(_coupleTheme, CoupleThemeSettings.fromJson);

  Future<void> writeCoupleTheme(CoupleThemeSettings settings) =>
      _prefs.setString(_coupleTheme, jsonEncode(settings.toJson()));

  AppearanceCatalog? readCatalog() =>
      _decode(_catalog, AppearanceCatalog.fromJson);

  Future<void> writeCatalog(AppearanceCatalog catalog) =>
      _prefs.setString(_catalog, jsonEncode(catalog.toJson()));

  /// Highest couple-theme version this user has seen; tells them when the partner changed it.
  int readSeenVersion() => _prefs.getInt(_seenVersion) ?? 0;

  Future<void> writeSeenVersion(int version) =>
      _prefs.setInt(_seenVersion, version);

  ThemeMode readThemeMode() =>
      ThemeMode.values
          .where((mode) => mode.name == _prefs.getString(_themeMode))
          .firstOrNull ??
      ThemeMode.system;

  Future<void> writeThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeMode, mode.name);

  bool readReduceMotion() => _prefs.getBool(_reduceMotion) ?? false;

  Future<void> writeReduceMotion(bool value) =>
      _prefs.setBool(_reduceMotion, value);

  /// On logout: the next account on this device must not inherit this couple's theme.
  Future<void> clearCoupleData() async {
    await _prefs.remove(_coupleTheme);
    await _prefs.remove(_catalog);
    await _prefs.remove(_seenVersion);
  }

  T? _decode<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;

    try {
      return fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      // Corrupt cache: ignore it, the server copy replaces it.
      return null;
    }
  }
}
