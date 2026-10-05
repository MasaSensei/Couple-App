import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/security/couple/couple_key.dart';
import 'package:frontend/core/security/photo/photo_key_service.dart';

void main() {
  test('derives a 256-bit photo key', () async {
    final service = PhotoKeyService();

    final coupleKey = CoupleKey(
      keyId: 'test-couple-key',
      secretKey: SecretKeyData.random(length: 32),
    );

    final photoKey = await service.deriveKey(
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    final bytes = await photoKey.extractBytes();

    expect(bytes, hasLength(32));
  });

  test('same couple key and photo id derive the same key', () async {
    final service = PhotoKeyService();

    final coupleKey = CoupleKey(
      keyId: 'test-couple-key',
      secretKey: SecretKeyData.random(length: 32),
    );

    final first = await service.deriveKey(
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    final second = await service.deriveKey(
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    final firstBytes = await first.extractBytes();

    final secondBytes = await second.extractBytes();

    expect(firstBytes, secondBytes);
  });

  test('different photo ids derive different keys', () async {
    final service = PhotoKeyService();

    final coupleKey = CoupleKey(
      keyId: 'test-couple-key',
      secretKey: SecretKeyData.random(length: 32),
    );

    final first = await service.deriveKey(
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    final second = await service.deriveKey(
      coupleKey: coupleKey,
      photoId: 'photo-2',
    );

    final firstBytes = await first.extractBytes();

    final secondBytes = await second.extractBytes();

    expect(firstBytes, isNot(equals(secondBytes)));
  });
}
