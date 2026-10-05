import 'package:frontend/core/security/device_key_service.dart';

import 'couple_key.dart';
import 'couple_key_package.dart';
import 'couple_key_package_repository.dart';
import 'couple_key_wrapper.dart';

class CoupleKeyPackageService {
  CoupleKeyPackageService({
    CoupleKeyPackageRepository? repository,
    DeviceKeyService? deviceKeyService,
    CoupleKeyWrapper? keyWrapper,
  }) : _repository = repository ?? CoupleKeyPackageRepository(),
       _deviceKeyService = deviceKeyService ?? DeviceKeyService(),
       _keyWrapper = keyWrapper ?? CoupleKeyWrapper();

  final CoupleKeyPackageRepository _repository;
  final DeviceKeyService _deviceKeyService;
  final CoupleKeyWrapper _keyWrapper;

  Future<CoupleKey> unwrapForCurrentDevice({required int deviceId}) async {
    final packages = await _repository.getKeyPackages();

    final package = _findPackage(packages, deviceId);

    final keyPair = await _deviceKeyService.loadKeyPair();

    try {
      final wrappedKey = WrappedCoupleKey.fromJson({
        'key_id': package.keyId,
        'encryption_version': package.encryptionVersion,
        'ephemeral_public_key': package.ephemeralPublicKey,
        'nonce': package.nonce,
        'ciphertext': package.ciphertext,
        'mac': package.mac,
      });

      final secretKey = await _keyWrapper.unwrap(
        wrappedKey: wrappedKey,
        recipientKeyPair: keyPair,
      );

      return CoupleKey(keyId: package.keyId, secretKey: secretKey);
    } finally {
      keyPair.destroy();
    }
  }

  CoupleKeyPackage _findPackage(List<CoupleKeyPackage> packages, int deviceId) {
    for (final package in packages) {
      if (package.deviceId == deviceId && package.revokedAt == null) {
        return package;
      }
    }

    throw StateError('No active couple key package found for this device.');
  }
}
