import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:frontend/core/security/device_repository.dart';

import 'couple_key.dart';
import 'couple_key_manager.dart';
import 'couple_key_package_repository.dart';
import 'couple_key_wrapper.dart';
import 'couple_key_package.dart';

class CoupleKeyProvisioningService {
  CoupleKeyProvisioningService({
    required this._keyManager,
    required this._packageRepository,
    required this._deviceRepository,
  });

  final CoupleKeyManager _keyManager;
  final CoupleKeyPackageRepository _packageRepository;
  final DeviceRepository _deviceRepository;
  final CoupleKeyWrapper _keyWrapper = CoupleKeyWrapper();

  Future<CoupleKey> provisionCurrentDevice({
    required String deviceIdentifier,
  }) async {
    // 1. Temukan perangkat yang aktif.
    final devices = await _deviceRepository.getDevices();

    Map<String, dynamic>? currentDevice;

    for (final device in devices) {
      if (device['device_identifier'] == deviceIdentifier &&
          device['revoked_at'] == null) {
        currentDevice = device;
        break;
      }
    }

    if (currentDevice == null) {
      throw StateError('Active device was not found.');
    }

    final deviceId = currentDevice['id'];
    final publicKeyValue = currentDevice['public_key'];

    if (deviceId is! int) {
      throw StateError('Invalid registered device ID.');
    }

    if (publicKeyValue is! String || publicKeyValue.isEmpty) {
      throw StateError('Device public key is missing.');
    }

    // 2. Periksa package yang tersimpan di server.
    final packages = await _packageRepository.getKeyPackages();

    CoupleKeyPackage? activePackage;

    for (final package in packages) {
      if (package.deviceId == deviceId && package.revokedAt == null) {
        if (activePackage != null) {
          throw StateError(
            'Multiple active key packages found for this device.',
          );
        }

        activePackage = package;
      }
    }

    // 3. Baca key lokal tanpa membuat key baru.
    final localKey = await _keyManager.getLocalKey();

    if (activePackage != null) {
      if (localKey != null) {
        // Jangan gunakan key lokal yang berbeda dari package server.
        if (localKey.keyId != activePackage.keyId) {
          throw StateError(
            'Local Couple Key does not match the active server package.',
          );
        }

        return localKey;
      }

      // Key lokal hilang: pulihkan dari package server.
      // Jika gagal, biarkan error muncul. Jangan membuat key baru.
      return _keyManager.getOrRestore(deviceId: deviceId);
    }

    // 4. Belum ada package untuk perangkat ini.
    // Gunakan key lokal yang ada, atau buat key baru jika memang belum ada.
    final coupleKey = localKey ?? await _keyManager.getOrCreate();

    final publicKey = SimplePublicKey(
      base64Decode(publicKeyValue),
      type: KeyPairType.x25519,
    );

    // 5. Bungkus Couple Key untuk perangkat ini.
    final wrappedKey = await _keyWrapper.wrap(
      keyId: coupleKey.keyId,
      coupleKey: coupleKey.secretKey,
      recipientPublicKey: publicKey,
    );

    // 6. Kirim hanya package terenkripsi ke backend.
    await _packageRepository.createKeyPackage(
      deviceId: deviceId,
      keyId: wrappedKey.keyId,
      encryptionVersion: wrappedKey.encryptionVersion,
      ephemeralPublicKey: base64Encode(wrappedKey.ephemeralPublicKey.bytes),
      nonce: base64Encode(wrappedKey.nonce),
      ciphertext: base64Encode(wrappedKey.ciphertext),
      mac: base64Encode(wrappedKey.mac),
    );

    return coupleKey;
  }
}
