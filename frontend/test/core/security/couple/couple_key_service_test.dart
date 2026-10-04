import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/security/couple/couple_key_service.dart';

void main() {
  group('CoupleKeyService', () {
    late CoupleKeyService service;

    setUp(() {
      service = CoupleKeyService();
    });

    test('generates a 32-byte couple key', () async {
      final key = await service.generateKey();

      final bytes = await key.extractBytes();

      expect(bytes.length, 32);
    });

    test('generates a different key each time', () async {
      final firstKey = await service.generateKey();
      final secondKey = await service.generateKey();

      final firstBytes = await firstKey.extractBytes();
      final secondBytes = await secondKey.extractBytes();

      expect(firstBytes, isNot(equals(secondBytes)));
    });

    test('generates a key suitable for 256-bit cryptography', () async {
      final key = await service.generateKey();

      final bytes = await key.extractBytes();

      expect(bytes.length * 8, 256);
    });
  });
}
