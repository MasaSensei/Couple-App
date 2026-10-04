import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/security/couple/couple_key_storage.dart';
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

void main() {
  group('CoupleKeyStorage', () {
    late FakeSecureStorage secureStorage;
    late CoupleKeyStorage storage;

    setUp(() {
      secureStorage = FakeSecureStorage();
      storage = CoupleKeyStorage(storage: secureStorage);
    });

    test('saves and reads couple key id', () async {
      await storage.save(
        keyId: 'key-123',
        secretKeyBytes: List<int>.filled(32, 1),
      );

      final keyId = await storage.readKeyId();

      expect(keyId, 'key-123');
    });

    test('saves and reads secret key bytes', () async {
      final secretKey = List<int>.generate(32, (index) => index);

      await storage.save(keyId: 'key-123', secretKeyBytes: secretKey);

      final result = await storage.readSecretKeyBytes();

      expect(result, secretKey);
    });

    test('returns null when secret key does not exist', () async {
      final result = await storage.readSecretKeyBytes();

      expect(result, isNull);
    });

    test('stores secret key encoded in secure storage', () async {
      final secretKey = List<int>.filled(32, 42);

      await storage.save(keyId: 'key-123', secretKeyBytes: secretKey);

      final storedValue = secureStorage.values['couple_secret_key'];

      expect(storedValue, isNotNull);
      expect(storedValue, isNot(secretKey.toString()));
    });
  });
}
