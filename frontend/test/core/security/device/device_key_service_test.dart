import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/security/device_key_service.dart';
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
  late DeviceKeyService service;

  setUp(() {
    secureStorage = FakeSecureStorage();

    service = DeviceKeyService(
      storage: DeviceKeyStorage(storage: secureStorage),
    );
  });

  test('initialize generates an X25519 key pair', () async {
    final publicKey = await service.initialize();

    final decodedPublicKey = base64Url.decode(publicKey);

    expect(decodedPublicKey, hasLength(32));
  });

  test('initialize does not replace existing private key', () async {
    final firstPublicKey = await service.initialize();
    final storedPrivateKey = secureStorage.values['device_private_key'];

    final secondPublicKey = await service.initialize();
    final storedPrivateKeyAfterSecondInitialize =
        secureStorage.values['device_private_key'];

    expect(secondPublicKey, firstPublicKey);
    expect(storedPrivateKeyAfterSecondInitialize, storedPrivateKey);
  });

  test('hasDeviceKey returns false before initialization', () async {
    expect(await service.hasDeviceKey(), isFalse);
  });

  test('hasDeviceKey returns true after initialization', () async {
    await service.initialize();

    expect(await service.hasDeviceKey(), isTrue);
  });
}
