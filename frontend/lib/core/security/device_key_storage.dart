import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureStorage {
  Future<void> write({required String key, required String value});

  Future<String?> read({required String key});
}

class FlutterSecureStorageAdapter implements SecureStorage {
  FlutterSecureStorageAdapter({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }
}

class DeviceKeyStorage {
  DeviceKeyStorage({SecureStorage? storage})
    : _storage = storage ?? FlutterSecureStorageAdapter();

  final SecureStorage _storage;

  static const _privateKeyKey = 'device_private_key';
  static const _deviceIdKey = 'device_id';

  Future<void> savePrivateKey(String value) {
    return _storage.write(key: _privateKeyKey, value: value);
  }

  Future<String?> readPrivateKey() {
    return _storage.read(key: _privateKeyKey);
  }

  Future<void> saveDeviceId(String value) {
    return _storage.write(key: _deviceIdKey, value: value);
  }

  Future<String?> readDeviceId() {
    return _storage.read(key: _deviceIdKey);
  }
}
