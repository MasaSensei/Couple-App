import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/security/device_identity_service.dart';
import 'package:frontend/core/security/device_key_storage.dart';

class FakeSecureStorage implements SecureStorage {
  final Map<String, String> values = {};

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return values[key];
  }
}

void main() {
  late FakeSecureStorage secureStorage;
  late DeviceIdentityService service;

  setUp(() {
    secureStorage = FakeSecureStorage();

    service = DeviceIdentityService(
      storage: DeviceKeyStorage(storage: secureStorage),
    );
  });

  test('creates a device id when none exists', () async {
    final deviceId = await service.getOrCreateDeviceId();

    expect(deviceId, isNotEmpty);
    expect(deviceId, matches(RegExp(r'^[0-9a-fA-F-]{36}$')));
  });

  test('returns the same device id on subsequent calls', () async {
    final firstDeviceId = await service.getOrCreateDeviceId();
    final secondDeviceId = await service.getOrCreateDeviceId();

    expect(secondDeviceId, firstDeviceId);
  });

  test('stores the generated device id', () async {
    final deviceId = await service.getOrCreateDeviceId();

    expect(secureStorage.values['device_id'], deviceId);
  });
}
