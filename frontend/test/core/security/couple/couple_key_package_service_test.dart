import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/security/couple/couple_key.dart';
import 'package:frontend/core/security/couple/couple_key_package.dart';
import 'package:frontend/core/security/couple/couple_key_package_repository.dart';
import 'package:frontend/core/security/couple/couple_key_package_service.dart';
import 'package:frontend/core/security/couple/couple_key_wrapper.dart';
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

class FakeCoupleKeyPackageRepository extends CoupleKeyPackageRepository {
  FakeCoupleKeyPackageRepository(this.packages);

  final List<CoupleKeyPackage> packages;

  @override
  Future<List<CoupleKeyPackage>> getKeyPackages() async {
    return packages;
  }
}

void main() {
  test('unwrapForCurrentDevice restores the couple key', () async {
    final secureStorage = FakeSecureStorage();

    final deviceKeyService = DeviceKeyService(
      storage: DeviceKeyStorage(storage: secureStorage),
    );

    await deviceKeyService.initialize();

    final deviceKeyPair = await deviceKeyService.loadKeyPair();

    final coupleKey = SecretKeyData.random(length: 32);

    final publicKey = await deviceKeyPair.extractPublicKey();

    final wrapper = CoupleKeyWrapper();

    final wrapped = await wrapper.wrap(
      keyId: 'test-key-id',
      coupleKey: coupleKey,
      recipientPublicKey: publicKey,
    );

    final package = CoupleKeyPackage(
      id: 1,
      deviceId: 123,
      keyId: wrapped.keyId,
      encryptionVersion: wrapped.encryptionVersion,
      ephemeralPublicKey: wrapped.toJson()['ephemeral_public_key'] as String,
      nonce: wrapped.toJson()['nonce'] as String,
      ciphertext: wrapped.toJson()['ciphertext'] as String,
      mac: wrapped.toJson()['mac'] as String,
      createdAt: null,
      updatedAt: null,
      revokedAt: null,
    );

    deviceKeyPair.destroy();

    final service = CoupleKeyPackageService(
      repository: FakeCoupleKeyPackageRepository([package]),
      deviceKeyService: deviceKeyService,
      keyWrapper: wrapper,
    );

    final result = await service.unwrapForCurrentDevice(deviceId: 123);

    expect(result, isA<CoupleKey>());
    expect(result.keyId, 'test-key-id');

    final originalBytes = await coupleKey.extractBytes();

    final restoredBytes = await result.secretKey.extractBytes();

    expect(restoredBytes, originalBytes);
  });

  test('unwrapForCurrentDevice fails when package does not exist', () async {
    final secureStorage = FakeSecureStorage();

    final deviceKeyService = DeviceKeyService(
      storage: DeviceKeyStorage(storage: secureStorage),
    );

    await deviceKeyService.initialize();

    final service = CoupleKeyPackageService(
      repository: FakeCoupleKeyPackageRepository([]),
      deviceKeyService: deviceKeyService,
    );

    expect(
      service.unwrapForCurrentDevice(deviceId: 123),
      throwsA(isA<StateError>()),
    );
  });
}
