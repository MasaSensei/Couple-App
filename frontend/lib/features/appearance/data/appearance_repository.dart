import 'package:frontend/core/error/api_exception.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/theme_customization.dart';

import 'appearance_models.dart';

class AppearanceRepository {
  AppearanceRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AppearanceCatalog> getCatalog() async {
    final response = await _apiClient.get('/appearance/catalog');

    return AppearanceCatalog.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<CoupleThemeSettings> getCoupleTheme() async {
    final response = await _apiClient.get('/couple/theme');

    return _settings(response.data);
  }

  /// Throws [ThemeConflictException] when the partner changed it first.
  Future<CoupleThemeSettings> updateCoupleTheme({
    required String themeKey,
    required ThemeCustomization customization,
    required int basedOnVersion,
  }) {
    return _guardConflict(() async {
      final response = await _apiClient.put(
        '/couple/theme',
        data: {
          'theme_key': themeKey,
          'customization': customization.toJson(),
          'version': basedOnVersion,
        },
      );

      return _settings(response.data);
    });
  }

  /// Throws [ThemeConflictException] when the partner changed it first.
  Future<CoupleThemeSettings> resetCustomization({
    required int basedOnVersion,
  }) {
    return _guardConflict(() async {
      final response = await _apiClient.delete(
        '/couple/theme/customization',
        data: {'version': basedOnVersion},
      );

      return _settings(response.data);
    });
  }

  Future<CoupleThemeSettings> _guardConflict(
    Future<CoupleThemeSettings> Function() request,
  ) async {
    try {
      return await request();
    } on ApiException catch (error) {
      final data = error.data;
      if (error.statusCode == 409 && data is Map && data['theme'] is Map) {
        throw ThemeConflictException(
          CoupleThemeSettings.fromJson(
            Map<String, dynamic>.from(data['theme'] as Map),
          ),
        );
      }
      rethrow;
    }
  }

  CoupleThemeSettings _settings(Object? body) {
    final data = (body as Map)['data'] as Map;

    return CoupleThemeSettings.fromJson(
      Map<String, dynamic>.from(data['theme'] as Map),
    );
  }
}
