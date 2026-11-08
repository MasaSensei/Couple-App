import 'package:flutter/foundation.dart';

/// Build-time configuration, one build per environment:
///
/// ```
/// flutter run                                   # dev (Android emulator → host)
/// flutter build appbundle --release \
///   --dart-define=APP_ENV=staging \
///   --dart-define=API_BASE_URL=https://staging-api.example.com/api/v1
/// flutter build appbundle --release \
///   --dart-define=APP_ENV=production \
///   --dart-define=API_BASE_URL=https://api.example.com/api/v1
/// ```
///
/// Only public values belong here. Secrets (store keys, signing, provider
/// credentials) live on the backend or in the CI signing step, never in the app.
abstract final class AppConfig {
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// `10.0.2.2` is the Android emulator's alias for the host machine.
  static const String _devApiBaseUrl = 'http://10.0.2.2:8000/api/v1';

  static bool get isProduction => environment == 'production';

  static String get apiBaseUrl {
    final url = _apiBaseUrl.isNotEmpty ? _apiBaseUrl : _devApiBaseUrl;
    validate(url: url, environment: environment, isRelease: kReleaseMode);
    return url;
  }

  /// Fails fast on a misconfigured build instead of shipping an app that talks
  /// to the emulator host or over cleartext HTTP.
  @visibleForTesting
  static void validate({
    required String url,
    required String environment,
    required bool isRelease,
  }) {
    const known = {'dev', 'staging', 'production'};
    if (!known.contains(environment)) {
      throw StateError('Unknown APP_ENV "$environment". Use one of $known.');
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('API_BASE_URL "$url" is not a valid URL.');
    }

    if (environment != 'dev' || isRelease) {
      if (uri.scheme != 'https') {
        throw StateError('$environment builds must use HTTPS (got $url).');
      }
      if (uri.host == '10.0.2.2' ||
          uri.host == 'localhost' ||
          uri.host == '127.0.0.1') {
        throw StateError(
          '$environment builds cannot point at a development host ($url).',
        );
      }
    }
  }
}
