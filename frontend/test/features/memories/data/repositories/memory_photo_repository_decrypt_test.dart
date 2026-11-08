import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/security/couple/couple_key.dart';
import 'package:frontend/core/security/encryption_errors.dart';
import 'package:frontend/core/security/photo/photo_encryption_service.dart';
import 'package:frontend/features/memories/data/models/memory_photo_model.dart';
import 'package:frontend/features/memories/data/repositories/memory_photo_repository.dart';

/// Serves whatever bytes "storage" holds, like the /content endpoint.
class FakeStorageRepository extends MemoryPhotoRepository {
  FakeStorageRepository(this.stored) : super(ApiClient());

  List<int> stored;

  @override
  Future<List<int>> getPhotoBytes({required int photoId}) async => stored;
}

void main() {
  const photoId = 42;
  final plaintext = utf8.encode('prepared jpeg bytes');
  final encryptionService = PhotoEncryptionService();

  late CoupleKey coupleKey;
  late EncryptedPhoto encrypted;
  late MemoryPhotoModel photo;

  setUp(() async {
    coupleKey = CoupleKey(
      keyId: 'couple-key',
      secretKey: SecretKey(List<int>.generate(32, (i) => i)),
    );

    encrypted = await encryptionService.encrypt(
      plaintext: plaintext,
      coupleKey: coupleKey,
      photoId: '$photoId',
    );

    photo = MemoryPhotoModel.fromJson({
      'id': photoId,
      'memory_id': 1,
      'uploaded_by': 1,
      'mime_type': 'image/jpeg',
      'file_size': plaintext.length,
      'encryption_version': 1,
      'encryption_algorithm': 'AES-256-GCM',
      'key_id': 'couple-key',
      'nonce': base64Encode(encrypted.nonce),
      'mac': base64Encode(encrypted.mac),
      'checksum': encrypted.checksum,
      'encrypted_size': encrypted.ciphertext.length,
      'status': 'verified',
      'sort_order': 0,
    });
  });

  Future<List<int>> decrypt(List<int> stored, {CoupleKey? key}) {
    return FakeStorageRepository(stored).getDecryptedPhotoBytes(
      photo: photo,
      coupleKey: key ?? coupleKey,
      encryptionService: encryptionService,
    );
  }

  test('same couple key decrypts the photo', () async {
    expect(await decrypt(encrypted.ciphertext), plaintext);
  });

  test('tampered ciphertext is rejected, never returned', () async {
    final tampered = List<int>.from(encrypted.ciphertext)..[0] ^= 1;

    await expectLater(
      decrypt(tampered),
      throwsA(isA<PhotoVerificationException>()),
    );
  });

  test('tampered MAC is rejected even when the checksum matches', () async {
    photo = MemoryPhotoModel.fromJson({
      ...{
        'id': photoId,
        'memory_id': 1,
        'uploaded_by': 1,
        'mime_type': 'image/jpeg',
        'file_size': plaintext.length,
        'encryption_version': 1,
        'encryption_algorithm': 'AES-256-GCM',
        'key_id': 'couple-key',
        'nonce': base64Encode(encrypted.nonce),
        'checksum': encrypted.checksum,
        'encrypted_size': encrypted.ciphertext.length,
        'status': 'verified',
        'sort_order': 0,
      },
      'mac': base64Encode(List<int>.filled(16, 0)),
    });

    await expectLater(
      decrypt(encrypted.ciphertext),
      throwsA(isA<PhotoVerificationException>()),
    );
  });

  test('truncated download is rejected', () async {
    await expectLater(
      decrypt(encrypted.ciphertext.sublist(1)),
      throwsA(isA<PhotoVerificationException>()),
    );
  });

  test('another couple key is reported as key unavailable', () async {
    final otherKey = CoupleKey(
      keyId: 'other-couple-key',
      secretKey: SecretKey(List<int>.filled(32, 7)),
    );

    await expectLater(
      decrypt(encrypted.ciphertext, key: otherKey),
      throwsA(isA<CoupleKeyUnavailableException>()),
    );
  });

  test(
    'wrong key material with a matching key id fails authentication',
    () async {
      final forgedKey = CoupleKey(
        keyId: 'couple-key',
        secretKey: SecretKey(List<int>.filled(32, 7)),
      );

      await expectLater(
        decrypt(encrypted.ciphertext, key: forgedKey),
        throwsA(isA<PhotoVerificationException>()),
      );
    },
  );
}
