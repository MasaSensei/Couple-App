import 'dart:io';

import 'package:frontend/core/security/device_identity_service.dart';
import 'package:frontend/core/security/device_key_service.dart';

import '../data/repositories/device_repository.dart';

class DeviceRegistrationService {
  DeviceRegistrationService({
    DeviceIdentityService? identityService,
    DeviceKeyService? keyService,
    DeviceRepository? repository,
    String? platform,
  }) : _identityService = identityService ?? DeviceIdentityService(),
       _keyService = keyService ?? DeviceKeyService(),
       _repository = repository ?? DeviceRepository(),
       _platform = platform ?? _detectPlatform();

  final DeviceIdentityService _identityService;
  final DeviceKeyService _keyService;
  final DeviceRepository _repository;
  final String _platform;

  Future<void> registerCurrentDevice({String? deviceName}) async {
    final deviceId = await _identityService.getOrCreateDeviceId();

    final publicKey = await _keyService.initialize();

    await _repository.registerDevice(
      deviceIdentifier: deviceId,
      deviceName: deviceName ?? 'My Device',
      platform: _platform,
      publicKey: publicKey,
    );
  }

  static String _detectPlatform() {
    if (Platform.isAndroid) {
      return 'android';
    }

    if (Platform.isIOS) {
      return 'ios';
    }

    throw UnsupportedError('Unsupported platform for device registration.');
  }
}
