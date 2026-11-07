import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API token in the platform keystore (Keychain / Android Keystore-backed).
class TokenStorage {
  TokenStorage() : _storage = const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _expiresAtKey = 'auth_token_expires_at';

  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token, {DateTime? expiresAt}) async {
    await _storage.write(key: _tokenKey, value: token);

    if (expiresAt == null) {
      await _storage.delete(key: _expiresAtKey);
    } else {
      await _storage.write(
        key: _expiresAtKey,
        value: expiresAt.toUtc().toIso8601String(),
      );
    }
  }

  Future<String?> getToken() {
    return _storage.read(key: _tokenKey);
  }

  /// Null for tokens issued before expiry was introduced.
  Future<DateTime?> getExpiresAt() async {
    final value = await _storage.read(key: _expiresAtKey);
    return value == null ? null : DateTime.tryParse(value);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _expiresAtKey);
  }
}
