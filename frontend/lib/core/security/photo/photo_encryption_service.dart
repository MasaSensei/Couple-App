import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'photo_key_service.dart';
import '../couple/couple_key.dart';
import 'photo_encryption_metadata.dart';

class PhotoEncryptionService {
  static const int encryptionVersion = 1;
  PhotoEncryptionService({AesGcm? aesGcm, PhotoKeyService? photoKeyService})
    : _aesGcm = aesGcm ?? AesGcm.with256bits(),
      _photoKeyService = photoKeyService ?? PhotoKeyService();

  final AesGcm _aesGcm;
  final PhotoKeyService _photoKeyService;

  Future<EncryptedPhoto> encrypt({
    required List<int> plaintext,
    required CoupleKey coupleKey,
    required String photoId,
  }) async {
    final photoKey = await _photoKeyService.deriveKey(
      coupleKey: coupleKey,
      photoId: photoId,
    );

    final nonce = _aesGcm.newNonce();

    final associatedData = _buildAssociatedData(
      keyId: coupleKey.keyId,
      encryptionVersion: encryptionVersion,
      photoId: photoId,
    );

    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: photoKey,
      nonce: nonce,
      aad: associatedData,
    );

    final checksum = await _calculateChecksum(secretBox.cipherText);

    return EncryptedPhoto(
      metadata: PhotoEncryptionMetadata(
        keyId: coupleKey.keyId,
        encryptionVersion: encryptionVersion,
      ),
      nonce: secretBox.nonce,
      ciphertext: secretBox.cipherText,
      mac: secretBox.mac.bytes,
      checksum: checksum,
    );
  }

  Future<String> _calculateChecksum(List<int> ciphertext) async {
    final digest = await Sha256().hash(ciphertext);

    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<List<int>> decrypt({
    required EncryptedPhoto encryptedPhoto,
    required CoupleKey coupleKey,
    required String photoId,
  }) async {
    final actualChecksum = await _calculateChecksum(encryptedPhoto.ciphertext);

    if (actualChecksum != encryptedPhoto.checksum) {
      throw StateError('Encrypted photo checksum mismatch.');
    }

    final photoKey = await _photoKeyService.deriveKey(
      coupleKey: coupleKey,
      photoId: photoId,
    );

    final secretBox = SecretBox(
      encryptedPhoto.ciphertext,
      nonce: encryptedPhoto.nonce,
      mac: Mac(encryptedPhoto.mac),
    );

    final associatedData = _buildAssociatedData(
      keyId: encryptedPhoto.metadata.keyId,
      encryptionVersion: encryptedPhoto.metadata.encryptionVersion,
      photoId: photoId,
    );

    return _aesGcm.decrypt(secretBox, secretKey: photoKey, aad: associatedData);
  }

  List<int> _buildAssociatedData({
    required String keyId,
    required int encryptionVersion,
    required String photoId,
  }) {
    return utf8.encode('$keyId:$encryptionVersion:$photoId');
  }
}

class EncryptedPhoto {
  const EncryptedPhoto({
    required this.metadata,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
    required this.checksum,
  });

  final PhotoEncryptionMetadata metadata;
  final List<int> nonce;
  final List<int> ciphertext;
  final List<int> mac;
  final String checksum;

  Map<String, dynamic> toJson() {
    return {
      ...metadata.toJson(),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(ciphertext),
      'mac': base64Encode(mac),
      'checksum': checksum,
    };
  }

  factory EncryptedPhoto.fromJson(Map<String, dynamic> json) {
    return EncryptedPhoto(
      metadata: PhotoEncryptionMetadata.fromJson(json),
      nonce: base64Decode(json['nonce'] as String),
      ciphertext: base64Decode(json['ciphertext'] as String),
      mac: base64Decode(json['mac'] as String),
      checksum: json['checksum'] as String,
    );
  }
}
