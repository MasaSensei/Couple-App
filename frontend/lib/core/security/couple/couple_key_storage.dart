import 'dart:convert';

import 'package:frontend/core/security/device_key_storage.dart';

class CoupleKeyStorage {
  CoupleKeyStorage({SecureStorage? storage})
    : _storage = storage ?? FlutterSecureStorageAdapter();

  final SecureStorage _storage;

  static const _keyIdKey = 'couple_key_id';
  static const _secretKeyKey = 'couple_secret_key';

  Future<void> save({
    required String keyId,
    required List<int> secretKeyBytes,
  }) async {
    await _storage.write(key: _keyIdKey, value: keyId);

    await _storage.write(
      key: _secretKeyKey,
      value: base64UrlEncode(secretKeyBytes),
    );
  }

  Future<String?> readKeyId() {
    return _storage.read(key: _keyIdKey);
  }

  Future<List<int>?> readSecretKeyBytes() async {
    final encoded = await _storage.read(key: _secretKeyKey);

    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    return base64Url.decode(encoded);
  }
}
