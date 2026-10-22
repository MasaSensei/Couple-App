import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:frontend/core/error/api_exception.dart';
import 'package:frontend/core/security/device_repository.dart';
import 'package:frontend/core/security/encryption_errors.dart';

import 'couple_device.dart';
import 'couple_key.dart';
import 'couple_key_manager.dart';
import 'couple_key_package.dart';
import 'couple_key_package_repository.dart';
import 'couple_key_recovery_service.dart';
import 'couple_key_wrapper.dart';

/// Every way a device obtains or shares the Couple Key:
/// create (first device of the couple), unwrap its own package,
/// approve another device, and Recovery Key backup/restore.
/// The server only ever receives encrypted key material.
class CoupleKeyProvisioningService {
  CoupleKeyProvisioningService({
    required this._keyManager,
    required this._packageRepository,
    required this._deviceRepository,
    CoupleKeyWrapper? keyWrapper,
    CoupleKeyRecoveryService? recoveryService,
  }) : _keyWrapper = keyWrapper ?? CoupleKeyWrapper(),
       _recoveryService = recoveryService ?? CoupleKeyRecoveryService();

  final CoupleKeyManager _keyManager;
  final CoupleKeyPackageRepository _packageRepository;
  final DeviceRepository _deviceRepository;
  final CoupleKeyWrapper _keyWrapper;
  final CoupleKeyRecoveryService _recoveryService;

  /// Returns the Couple Key for this device, or throws
  /// [CoupleKeyUnavailableException] when the couple already has a key that
  /// this device has not been given. Never creates a second key for a couple.
  Future<CoupleKey> provisionCurrentDevice({
    required String deviceIdentifier,
  }) async {
    final device = await _currentDevice(deviceIdentifier);
    final packages = await _activePackages();
    final localKey = await _keyManager.getLocalKey();

    final ownPackages = packages.where((p) => p.deviceId == device.id);

    if (ownPackages.length > 1) {
      throw StateError('Multiple active key packages found for this device.');
    }

    if (ownPackages.isNotEmpty) {
      if (localKey == null) {
        return _keyManager.getOrRestore(deviceId: device.id);
      }

      // Never let the server swap a key this device already trusts.
      if (localKey.keyId != ownPackages.single.keyId) {
        throw const CoupleKeyUnavailableException();
      }

      return localKey;
    }

    final coupleKeyId = packages.isEmpty ? null : packages.first.keyId;

    if (coupleKeyId != null && localKey?.keyId != coupleKeyId) {
      throw const CoupleKeyUnavailableException();
    }

    // Either the key came from recovery, or this is the couple's first device.
    final coupleKey = localKey ?? await _keyManager.generate();

    try {
      await _uploadPackage(coupleKey, device.id, device.publicKey);
    } on ApiException catch (error) {
      // 409: another device established the couple key first.
      if (error.statusCode == 409) throw const CoupleKeyUnavailableException();
      rethrow;
    }

    // Saved only after the server accepted it, so a failed upload leaves no stray key.
    if (localKey == null) await _keyManager.save(coupleKey);

    return coupleKey;
  }

  /// Active devices (own or partner's) that do not have the Couple Key yet.
  Future<List<CoupleDevice>> pendingDevices() async {
    final coupleKey = await _requireLocalKey();
    final packages = await _activePackages();

    final authorized = packages
        .where((p) => p.keyId == coupleKey.keyId)
        .map((p) => p.deviceId)
        .toSet();

    final devices = await _packageRepository.getCoupleDevices();

    return devices.where((d) => !authorized.contains(d.id)).toList();
  }

  /// Shares the Couple Key with [device]. The UI must confirm the device
  /// fingerprint with the user first.
  Future<void> authorizeDevice(CoupleDevice device) async {
    final coupleKey = await _requireLocalKey();

    await _uploadPackage(coupleKey, device.id, device.publicKey);
  }

  Future<bool> hasRecoveryKey() async {
    return await _packageRepository.getRecoveryPackage() != null;
  }

  /// A new Recovery Key, formatted for the user. Nothing is uploaded yet.
  Future<String> generateRecoveryKey() async {
    return _recoveryService.formatRecoveryKey(
      await _recoveryService.generateRecoveryKey(),
    );
  }

  /// Uploads the Couple Key encrypted with [recoveryKeyText].
  /// The Recovery Key itself never leaves the device.
  Future<void> saveRecoveryKey(String recoveryKeyText) async {
    final coupleKey = await _requireLocalKey();

    final payload = await _recoveryService.createRecoveryPayload(
      coupleKey: coupleKey,
      recoveryKey: _recoveryService.parseRecoveryKey(recoveryKeyText),
    );

    await _packageRepository.putRecoveryPackage(payload);
  }

  /// Restores the Couple Key on this device. Throws [FormatException] for a
  /// wrong Recovery Key and [RecoveryUnavailableException] when none was set up.
  Future<CoupleKey> restoreWithRecoveryKey({
    required String deviceIdentifier,
    required String recoveryKeyText,
  }) async {
    final recoveryKey = _recoveryService.parseRecoveryKey(recoveryKeyText);
    final payload = await _packageRepository.getRecoveryPackage();

    if (payload == null) throw const RecoveryUnavailableException();

    final coupleKey = await _recoveryService.restoreFromRecoveryPayload(
      payload: payload,
      recoveryKey: recoveryKey,
    );

    // The user proved ownership of the Recovery Key, so it replaces any local key.
    await _keyManager.save(coupleKey);

    return provisionCurrentDevice(deviceIdentifier: deviceIdentifier);
  }

  Future<CoupleKey> _requireLocalKey() async {
    final localKey = await _keyManager.getLocalKey();

    if (localKey == null) throw const CoupleKeyUnavailableException();

    return localKey;
  }

  Future<List<CoupleKeyPackage>> _activePackages() async {
    final packages = await _packageRepository.getKeyPackages();

    return packages.where((p) => p.revokedAt == null).toList();
  }

  Future<void> _uploadPackage(
    CoupleKey coupleKey,
    int deviceId,
    String publicKeyBase64,
  ) async {
    final wrappedKey = await _keyWrapper.wrap(
      keyId: coupleKey.keyId,
      coupleKey: coupleKey.secretKey,
      recipientPublicKey: SimplePublicKey(
        base64Decode(publicKeyBase64),
        type: KeyPairType.x25519,
      ),
    );

    await _packageRepository.createKeyPackage(
      deviceId: deviceId,
      keyId: wrappedKey.keyId,
      encryptionVersion: wrappedKey.encryptionVersion,
      ephemeralPublicKey: base64Encode(wrappedKey.ephemeralPublicKey.bytes),
      nonce: base64Encode(wrappedKey.nonce),
      ciphertext: base64Encode(wrappedKey.ciphertext),
      mac: base64Encode(wrappedKey.mac),
    );
  }

  Future<({int id, String publicKey})> _currentDevice(
    String deviceIdentifier,
  ) async {
    final devices = await _deviceRepository.getDevices();

    for (final device in devices) {
      if (device['device_identifier'] == deviceIdentifier &&
          device['revoked_at'] == null) {
        final id = device['id'];
        final publicKey = device['public_key'];

        if (id is! int || publicKey is! String || publicKey.isEmpty) {
          throw const FormatException('Invalid registered device.');
        }

        return (id: id, publicKey: publicKey);
      }
    }

    throw StateError('Active device was not found.');
  }
}
