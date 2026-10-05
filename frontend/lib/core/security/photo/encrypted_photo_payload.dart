import 'dart:convert';

import 'photo_encryption_service.dart';

class EncryptedPhotoPayload {
  const EncryptedPhotoPayload({
    required this.keyId,
    required this.encryptionVersion,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
    required this.checksum,
  });

  final String keyId;
  final int encryptionVersion;
  final String nonce;
  final String ciphertext;
  final String mac;
  final String checksum;

  factory EncryptedPhotoPayload.fromEncryptedPhoto(
    EncryptedPhoto encryptedPhoto,
  ) {
    return EncryptedPhotoPayload(
      keyId: encryptedPhoto.metadata.keyId,
      encryptionVersion: encryptedPhoto.metadata.encryptionVersion,
      nonce: base64Encode(encryptedPhoto.nonce),
      ciphertext: base64Encode(encryptedPhoto.ciphertext),
      mac: base64Encode(encryptedPhoto.mac),
      checksum: encryptedPhoto.checksum,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key_id': keyId,
      'encryption_version': encryptionVersion,
      'nonce': nonce,
      'ciphertext': ciphertext,
      'mac': mac,
      'checksum': checksum,
    };
  }
}
