import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/security/couple/couple_key.dart';
import 'package:frontend/core/security/photo/encrypted_photo_payload.dart';
import 'package:frontend/core/security/photo/photo_encryption_service.dart';

void main() {
  test('encrypted photo can be converted to api payload', () async {
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

    final payload = EncryptedPhotoPayload.fromEncryptedPhoto(encrypted);

    expect(payload.keyId, encrypted.metadata.keyId);

    expect(payload.encryptionVersion, encrypted.metadata.encryptionVersion);

    expect(payload.nonce, isA<String>());

    expect(payload.ciphertext, isA<String>());

    expect(payload.mac, isA<String>());

    expect(payload.checksum, encrypted.checksum);
  });

  test('encrypted photo payload serializes to api json', () async {
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

    final payload = EncryptedPhotoPayload.fromEncryptedPhoto(encrypted);

    final json = payload.toJson();

    expect(json['key_id'], payload.keyId);
    expect(json['encryption_version'], payload.encryptionVersion);
    expect(json['nonce'], payload.nonce);
    expect(json['ciphertext'], payload.ciphertext);
    expect(json['mac'], payload.mac);
    expect(json['checksum'], payload.checksum);
  });
}
