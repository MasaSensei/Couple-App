import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/security/couple/couple_key_manager.dart';
import 'package:frontend/core/security/couple/couple_key_service.dart';
import 'package:frontend/core/security/couple/couple_key_storage.dart';

class FakeCoupleKeyService extends CoupleKeyService {
  FakeCoupleKeyService(this.keyBytes);

  final List<int> keyBytes;

  @override
  Future<SecretKey> generateKey() async {
    return SecretKey(keyBytes);
  }
}

class FakeCoupleKeyStorage extends CoupleKeyStorage {
  String? keyId;
  List<int>? secretKeyBytes;

  @override
  Future<void> save({
    required String keyId,
    required List<int> secretKeyBytes,
  }) async {
    this.keyId = keyId;
    this.secretKeyBytes = List<int>.from(secretKeyBytes);
  }

  @override
  Future<String?> readKeyId() async {
    return keyId;
  }

  @override
  Future<List<int>?> readSecretKeyBytes() async {
    return secretKeyBytes == null ? null : List<int>.from(secretKeyBytes!);
  }
}

void main() {
  group('CoupleKeyManager', () {
    test('creates and stores a couple key when none exists', () async {
      final storage = FakeCoupleKeyStorage();

      final manager = CoupleKeyManager(
        keyService: FakeCoupleKeyService(
          List<int>.generate(32, (index) => index),
        ),
        storage: storage,
      );

      final coupleKey = await manager.getOrCreate();

      expect(coupleKey.keyId, isNotEmpty);
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(coupleKey.keyId),
        isTrue,
      );

      final bytes = await coupleKey.secretKey.extractBytes();

      expect(bytes, List<int>.generate(32, (index) => index));

      expect(storage.keyId, coupleKey.keyId);
      expect(storage.secretKeyBytes, bytes);
    });

    test('returns existing couple key without generating a new one', () async {
      final storage = FakeCoupleKeyStorage()
        ..keyId = 'existing-key'
        ..secretKeyBytes = List<int>.filled(32, 42);

      final manager = CoupleKeyManager(
        keyService: FakeCoupleKeyService(List<int>.filled(32, 99)),
        storage: storage,
      );

      final coupleKey = await manager.getOrCreate();

      expect(coupleKey.keyId, 'existing-key');

      final bytes = await coupleKey.secretKey.extractBytes();

      expect(bytes, List<int>.filled(32, 42));
    });
  });
}
