import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/security/couple/couple_key.dart';
import 'package:frontend/core/security/photo/photo_encryption_metadata.dart';
import 'package:frontend/core/security/photo/photo_encryption_service.dart';

void main() {
  test('encrypt returns ciphertext, nonce, and mac', () async {
    final service = PhotoEncryptionService();

    final coupleKey = CoupleKey(
      keyId: 'test-couple-key',
      secretKey: SecretKeyData.random(length: 32),
    );

    final plaintext = <int>[1, 2, 3, 4, 5];

    final result = await service.encrypt(
      plaintext: plaintext,
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    expect(result.nonce, hasLength(12));
    expect(result.ciphertext, hasLength(5));
    expect(result.mac, hasLength(16));
  });

  test('encrypt does not expose plaintext as ciphertext', () async {
    final service = PhotoEncryptionService();

    final coupleKey = CoupleKey(
      keyId: 'test-couple-key',
      secretKey: SecretKeyData.random(length: 32),
    );

    final plaintext = <int>[10, 20, 30, 40];

    final result = await service.encrypt(
      plaintext: plaintext,
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    expect(result.ciphertext, isNot(equals(plaintext)));
  });

  test(
    'encrypting the same plaintext twice produces different ciphertext',
    () async {
      final service = PhotoEncryptionService();

      final coupleKey = CoupleKey(
        keyId: 'test-couple-key',
        secretKey: SecretKeyData.random(length: 32),
      );

      final plaintext = <int>[1, 2, 3, 4, 5];

      final first = await service.encrypt(
        plaintext: plaintext,
        coupleKey: coupleKey,
        photoId: 'photo-1',
      );

      final second = await service.encrypt(
        plaintext: plaintext,
        coupleKey: coupleKey,
        photoId: 'photo-1',
      );

      expect(first.ciphertext, isNot(equals(second.ciphertext)));

      expect(first.nonce, isNot(equals(second.nonce)));
    },
  );

  test('decrypt restores the original plaintext', () async {
    final service = PhotoEncryptionService();

    final coupleKey = CoupleKey(
      keyId: 'test-couple-key',
      secretKey: SecretKeyData.random(length: 32),
    );

    final plaintext = <int>[10, 20, 30, 40, 50];

    final encrypted = await service.encrypt(
      plaintext: plaintext,
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    final decrypted = await service.decrypt(
      encryptedPhoto: encrypted,
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    expect(decrypted, plaintext);
  });

  test('decrypt fails when ciphertext is tampered', () async {
    final service = PhotoEncryptionService();

    final coupleKey = CoupleKey(
      keyId: 'test-couple-key',
      secretKey: SecretKeyData.random(length: 32),
    );

    final plaintext = <int>[10, 20, 30, 40];

    final encrypted = await service.encrypt(
      plaintext: plaintext,
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    final tamperedCiphertext = List<int>.from(encrypted.ciphertext);

    tamperedCiphertext[0] ^= 1;

    final tampered = EncryptedPhoto(
      metadata: PhotoEncryptionMetadata(
        keyId: encrypted.metadata.keyId,
        encryptionVersion: encrypted.metadata.encryptionVersion + 1,
      ),
      nonce: encrypted.nonce,
      ciphertext: encrypted.ciphertext,
      mac: encrypted.mac,
      checksum: encrypted.checksum,
    );

    expect(
      service.decrypt(
        encryptedPhoto: tampered,
        coupleKey: coupleKey,
        photoId: 'photo-1',
      ),
      throwsA(anything),
    );
  });

  test('decrypt fails when mac is tampered', () async {
    final service = PhotoEncryptionService();

    final coupleKey = CoupleKey(
      keyId: 'test-couple-key',
      secretKey: SecretKeyData.random(length: 32),
    );

    final encrypted = await service.encrypt(
      plaintext: [1, 2, 3, 4],
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    final tamperedMac = List<int>.from(encrypted.mac);

    tamperedMac[0] ^= 1;

    final tampered = EncryptedPhoto(
      metadata: PhotoEncryptionMetadata(
        keyId: encrypted.metadata.keyId,
        encryptionVersion: encrypted.metadata.encryptionVersion + 1,
      ),
      nonce: encrypted.nonce,
      ciphertext: encrypted.ciphertext,
      mac: encrypted.mac,
      checksum: encrypted.checksum,
    );

    expect(
      service.decrypt(
        encryptedPhoto: tampered,
        coupleKey: coupleKey,
        photoId: 'photo-1',
      ),
      throwsA(anything),
    );
  });

  test('decrypt fails when using a different photo id', () async {
    final service = PhotoEncryptionService();

    final coupleKey = CoupleKey(
      keyId: 'test-couple-key',
      secretKey: SecretKeyData.random(length: 32),
    );

    final encrypted = await service.encrypt(
      plaintext: [1, 2, 3, 4],
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    expect(
      service.decrypt(
        encryptedPhoto: encrypted,
        coupleKey: coupleKey,
        photoId: 'photo-2',
      ),
      throwsA(anything),
    );
  });

  test('decrypt fails when key id is tampered', () async {
    final service = PhotoEncryptionService();

    final coupleKey = CoupleKey(
      keyId: 'test-couple-key',
      secretKey: SecretKeyData.random(length: 32),
    );

    final encrypted = await service.encrypt(
      plaintext: [1, 2, 3, 4],
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    final tampered = EncryptedPhoto(
      metadata: PhotoEncryptionMetadata(
        keyId: 'another-key',
        encryptionVersion: encrypted.metadata.encryptionVersion,
      ),
      nonce: encrypted.nonce,
      ciphertext: encrypted.ciphertext,
      mac: encrypted.mac,
      checksum: encrypted.checksum,
    );

    expect(
      service.decrypt(
        encryptedPhoto: tampered,
        coupleKey: coupleKey,
        photoId: 'photo-1',
      ),
      throwsA(anything),
    );
  });

  test('decrypt fails when encryption version is tampered', () async {
    final service = PhotoEncryptionService();

    final coupleKey = CoupleKey(
      keyId: 'test-couple-key',
      secretKey: SecretKeyData.random(length: 32),
    );

    final encrypted = await service.encrypt(
      plaintext: [1, 2, 3, 4],
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    final tampered = EncryptedPhoto(
      metadata: PhotoEncryptionMetadata(
        keyId: encrypted.metadata.keyId,
        encryptionVersion: encrypted.metadata.encryptionVersion + 1,
      ),
      nonce: encrypted.nonce,
      ciphertext: encrypted.ciphertext,
      mac: encrypted.mac,
      checksum: encrypted.checksum,
    );

    expect(
      service.decrypt(
        encryptedPhoto: tampered,
        coupleKey: coupleKey,
        photoId: 'photo-1',
      ),
      throwsA(anything),
    );
  });

  test('decrypt fails when photo id is different', () async {
    final service = PhotoEncryptionService();

    final coupleKey = CoupleKey(
      keyId: 'test-couple-key',
      secretKey: SecretKeyData.random(length: 32),
    );

    final encrypted = await service.encrypt(
      plaintext: [1, 2, 3, 4],
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    expect(
      service.decrypt(
        encryptedPhoto: encrypted,
        coupleKey: coupleKey,
        photoId: 'photo-2',
      ),
      throwsA(anything),
    );
  });

  test('encrypted photo survives json serialization', () async {
    final service = PhotoEncryptionService();

    final coupleKey = CoupleKey(
      keyId: 'test-couple-key',
      secretKey: SecretKeyData.random(length: 32),
    );

    final plaintext = <int>[10, 20, 30, 40, 50];

    final encrypted = await service.encrypt(
      plaintext: plaintext,
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    final json = encrypted.toJson();

    final restored = EncryptedPhoto.fromJson(json);

    final decrypted = await service.decrypt(
      encryptedPhoto: restored,
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    expect(decrypted, plaintext);
    expect(restored.metadata.keyId, encrypted.metadata.keyId);

    expect(
      restored.metadata.encryptionVersion,
      encrypted.metadata.encryptionVersion,
    );
    expect(restored.nonce, encrypted.nonce);
    expect(restored.ciphertext, encrypted.ciphertext);
    expect(restored.mac, encrypted.mac);
    expect(restored.checksum, encrypted.checksum);
  });

  test('encrypted photo json contains base64 strings', () async {
    final service = PhotoEncryptionService();

    final coupleKey = CoupleKey(
      keyId: 'test-couple-key',
      secretKey: SecretKeyData.random(length: 32),
    );

    final encrypted = await service.encrypt(
      plaintext: [1, 2, 3, 4],
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    final json = encrypted.toJson();

    expect(json['key_id'], isA<String>());
    expect(json['encryption_version'], isA<int>());
    expect(json['nonce'], isA<String>());
    expect(json['ciphertext'], isA<String>());
    expect(json['mac'], isA<String>());
  });

  test('encrypt generates a sha256 ciphertext checksum', () async {
    final service = PhotoEncryptionService();

    final coupleKey = CoupleKey(
      keyId: 'test-couple-key',
      secretKey: SecretKeyData.random(length: 32),
    );

    final encrypted = await service.encrypt(
      plaintext: [1, 2, 3, 4],
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    expect(encrypted.checksum, hasLength(64));
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(encrypted.checksum), isTrue);
  });

  test('decrypt fails when ciphertext checksum does not match', () async {
    final service = PhotoEncryptionService();

    final coupleKey = CoupleKey(
      keyId: 'test-couple-key',
      secretKey: SecretKeyData.random(length: 32),
    );

    final encrypted = await service.encrypt(
      plaintext: [1, 2, 3, 4],
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    final tampered = EncryptedPhoto(
      metadata: PhotoEncryptionMetadata(
        keyId: encrypted.metadata.keyId,
        encryptionVersion: encrypted.metadata.encryptionVersion,
      ),
      nonce: encrypted.nonce,
      ciphertext: encrypted.ciphertext,
      mac: encrypted.mac,
      checksum: '0' * 64,
    );

    expect(
      service.decrypt(
        encryptedPhoto: tampered,
        coupleKey: coupleKey,
        photoId: 'photo-1',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('encrypted photo uses encryption version 1', () async {
    final service = PhotoEncryptionService();

    final coupleKey = CoupleKey(
      keyId: 'test-couple-key',
      secretKey: SecretKeyData.random(length: 32),
    );

    final encrypted = await service.encrypt(
      plaintext: [1, 2, 3],
      coupleKey: coupleKey,
      photoId: 'photo-1',
    );

    expect(
      encrypted.metadata.encryptionVersion,
      PhotoEncryptionService.encryptionVersion,
    );
  });
}
