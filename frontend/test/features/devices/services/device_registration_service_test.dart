import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/error/api_exception.dart';
import 'package:frontend/core/security/couple/couple_key_storage.dart';
import 'package:frontend/core/security/device_key_storage.dart';
import 'package:frontend/core/security/device_identity_service.dart';
import 'package:frontend/core/security/device_key_service.dart';

import 'package:frontend/features/device/data/repositories/device_repository.dart';
import 'package:frontend/features/device/services/device_registration_service.dart';

class FakeDeviceIdentityService extends DeviceIdentityService {
  FakeDeviceIdentityService(this.deviceId);

  final String deviceId;

  @override
  Future<String> getOrCreateDeviceId() async {
    return deviceId;
  }
}

class FakeDeviceKeyService extends DeviceKeyService {
  FakeDeviceKeyService(this.publicKey);

  final String publicKey;

  @override
  Future<String> initialize() async {
    return publicKey;
  }
}

class FakeDeviceRepository extends DeviceRepository {
  String? deviceIdentifier;
  String? deviceName;
  String? platform;
  String? publicKey;

  @override
  Future<void> registerDevice({
    required String deviceIdentifier,
    required String deviceName,
    required String platform,
    required String publicKey,
  }) async {
    this.deviceIdentifier = deviceIdentifier;
    this.deviceName = deviceName;
    this.platform = platform;
    this.publicKey = publicKey;
  }
}

void main() {
  test(
    'registers current device with generated identity and public key',
    () async {
      final identityService = FakeDeviceIdentityService('device-id-test');

      final keyService = FakeDeviceKeyService('public-key-test');

      final repository = FakeDeviceRepository();

      final service = DeviceRegistrationService(
        identityService: identityService,
        keyService: keyService,
        repository: repository,
        platform: 'android',
      );

      await service.registerCurrentDevice(deviceName: 'Test Phone');

      expect(repository.deviceIdentifier, 'device-id-test');

      expect(repository.deviceName, 'Test Phone');

      expect(repository.publicKey, 'public-key-test');

      expect(repository.platform, 'android');
    },
  );

  test('uses default device name when none is provided', () async {
    final repository = FakeDeviceRepository();

    final service = DeviceRegistrationService(
      identityService: FakeDeviceIdentityService('device-id-test'),
      keyService: FakeDeviceKeyService('public-key-test'),
      repository: repository,
      platform: 'android',
    );

    await service.registerCurrentDevice();

    expect(repository.deviceName, 'My Device');
  });

  test(
    'revoked device forgets its keys and registers as a new device',
    () async {
      final storage = _MemorySecureStorage();
      final deviceKeyStorage = DeviceKeyStorage(storage: storage);
      final coupleKeyStorage = CoupleKeyStorage(storage: storage);

      await coupleKeyStorage.save(
        keyId: 'k',
        secretKeyBytes: List.filled(32, 1),
      );

      final identityService = DeviceIdentityService(storage: deviceKeyStorage);
      final firstIdentifier = await identityService.getOrCreateDeviceId();
      final keyService = DeviceKeyService(storage: deviceKeyStorage);
      final firstPublicKey = await keyService.initialize();

      final repository = _RevokingDeviceRepository(firstIdentifier);

      await DeviceRegistrationService(
        identityService: identityService,
        keyService: keyService,
        repository: repository,
        deviceKeyStorage: deviceKeyStorage,
        coupleKeyStorage: coupleKeyStorage,
        platform: 'android',
      ).registerCurrentDevice();

      expect(repository.registered, hasLength(2));
      expect(repository.registered.last.$1, isNot(firstIdentifier));
      expect(repository.registered.last.$2, isNot(firstPublicKey));
      expect(await coupleKeyStorage.readSecretKeyBytes(), isNull);
    },
  );
}

class _MemorySecureStorage implements SecureStorage {
  final values = <String, String>{};

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => values[key];
}

class _RevokingDeviceRepository extends DeviceRepository {
  _RevokingDeviceRepository(this.revokedIdentifier);

  final String revokedIdentifier;
  final registered = <(String, String)>[];

  @override
  Future<void> registerDevice({
    required String deviceIdentifier,
    required String deviceName,
    required String platform,
    required String publicKey,
  }) async {
    registered.add((deviceIdentifier, publicKey));

    if (deviceIdentifier == revokedIdentifier) {
      throw const ApiException(message: 'revoked', statusCode: 403);
    }
  }
}
