import 'package:flutter_test/flutter_test.dart';
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
}
