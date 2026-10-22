import 'dart:io';

import 'package:frontend/core/error/api_exception.dart';
import 'package:frontend/core/security/couple/couple_key_storage.dart';
import 'package:frontend/core/security/device_identity_service.dart';
import 'package:frontend/core/security/device_key_service.dart';
import 'package:frontend/core/security/device_key_storage.dart';

import '../data/repositories/device_repository.dart';

class DeviceRegistrationService {
  DeviceRegistrationService({
    DeviceIdentityService? identityService,
    DeviceKeyService? keyService,
    DeviceRepository? repository,
    DeviceKeyStorage? deviceKeyStorage,
    CoupleKeyStorage? coupleKeyStorage,
    String? platform,
  }) : _identityService = identityService ?? DeviceIdentityService(),
       _deviceKeyStorage = deviceKeyStorage ?? DeviceKeyStorage(),
       _coupleKeyStorage = coupleKeyStorage ?? CoupleKeyStorage(),
       _keyService = keyService ?? DeviceKeyService(),
       _repository = repository ?? DeviceRepository(),
       _platform = platform ?? _detectPlatform();

  final DeviceIdentityService _identityService;
  final DeviceKeyService _keyService;
  final DeviceRepository _repository;
  final DeviceKeyStorage _deviceKeyStorage;
  final CoupleKeyStorage _coupleKeyStorage;
  final String _platform;

  Future<void> registerCurrentDevice({String? deviceName}) async {
    try {
      await _register(deviceName);
    } on ApiException catch (error) {
      if (error.statusCode != 403) rethrow;

      // This device was revoked. Forget its keys and join as a new device,
      // which must be approved again before it can open photos.
      await _coupleKeyStorage.clear();
      await _deviceKeyStorage.clear();
      await _register(deviceName);
    }
  }

  Future<void> _register(String? deviceName) async {
    final deviceIdentifier = await _identityService.getOrCreateDeviceId();

    final publicKey = await _keyService.initialize();

    await _repository.registerDevice(
      deviceIdentifier: deviceIdentifier,
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
