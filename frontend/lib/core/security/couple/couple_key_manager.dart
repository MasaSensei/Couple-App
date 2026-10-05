import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import 'couple_key.dart';
import 'couple_key_service.dart';
import 'couple_key_storage.dart';
import 'couple_key_package_service.dart';

class CoupleKeyManager {
  CoupleKeyManager({
    CoupleKeyService? keyService,
    CoupleKeyStorage? storage,
    Uuid? uuid,
    CoupleKeyPackageService? packageService,
  }) : _keyService = keyService ?? CoupleKeyService(),
       _storage = storage ?? CoupleKeyStorage(),
       _uuid = uuid ?? const Uuid(),
       _packageService = packageService ?? CoupleKeyPackageService();

  final CoupleKeyService _keyService;
  final CoupleKeyStorage _storage;
  final Uuid _uuid;
  final CoupleKeyPackageService _packageService;

  Future<CoupleKey> getOrCreate() async {
    final existingKeyId = await _storage.readKeyId();
    final existingKeyBytes = await _storage.readSecretKeyBytes();

    if (existingKeyId != null &&
        existingKeyId.isNotEmpty &&
        existingKeyBytes != null) {
      return CoupleKey(
        keyId: existingKeyId,
        secretKey: SecretKey(existingKeyBytes),
      );
    }

    final secretKey = await _keyService.generateKey();
    final secretKeyBytes = await secretKey.extractBytes();
    final keyId = _uuid.v4();

    await _storage.save(keyId: keyId, secretKeyBytes: secretKeyBytes);

    return CoupleKey(keyId: keyId, secretKey: SecretKey(secretKeyBytes));
  }

  Future<void> save(CoupleKey coupleKey) async {
    final secretKeyBytes = await coupleKey.secretKey.extractBytes();

    await _storage.save(keyId: coupleKey.keyId, secretKeyBytes: secretKeyBytes);
  }

  Future<CoupleKey> getOrRestore({required int deviceId}) async {
    final existingKeyId = await _storage.readKeyId();

    final existingKeyBytes = await _storage.readSecretKeyBytes();

    if (existingKeyId != null &&
        existingKeyId.isNotEmpty &&
        existingKeyBytes != null) {
      return CoupleKey(
        keyId: existingKeyId,
        secretKey: SecretKey(existingKeyBytes),
      );
    }

    final coupleKey = await _packageService.unwrapForCurrentDevice(
      deviceId: deviceId,
    );

    await save(coupleKey);

    return coupleKey;
  }
}
