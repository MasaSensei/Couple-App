import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/security/device_key_storage.dart';

class FakeSecureStorage implements SecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<void> write({required String key, required String value}) async {
    _storage[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return _storage[key];
  }
}

void main() {
  late FakeSecureStorage fakeStorage;
  late DeviceKeyStorage storage;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    storage = DeviceKeyStorage(storage: fakeStorage);
  });

  test('can save and read private key', () async {
    const privateKey = 'private-key-test';

    await storage.savePrivateKey(privateKey);

    final result = await storage.readPrivateKey();

    expect(result, privateKey);
  });

  test('can save and read device id', () async {
    const deviceId = 'device-id-test';

    await storage.saveDeviceId(deviceId);

    final result = await storage.readDeviceId();

    expect(result, deviceId);
  });

  test('returns null when private key does not exist', () async {
    final result = await storage.readPrivateKey();

    expect(result, isNull);
  });

  test('returns null when device id does not exist', () async {
    final result = await storage.readDeviceId();

    expect(result, isNull);
  });
}
