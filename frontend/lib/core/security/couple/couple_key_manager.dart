import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import 'couple_key.dart';
import 'couple_key_service.dart';
import 'couple_key_storage.dart';

class CoupleKeyManager {
  CoupleKeyManager({
    CoupleKeyService? keyService,
    CoupleKeyStorage? storage,
    Uuid? uuid,
  }) : _keyService = keyService ?? CoupleKeyService(),
       _storage = storage ?? CoupleKeyStorage(),
       _uuid = uuid ?? const Uuid();

  final CoupleKeyService _keyService;
  final CoupleKeyStorage _storage;
  final Uuid _uuid;

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
}
