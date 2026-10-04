import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class CoupleKeyWrapper {
  CoupleKeyWrapper({X25519? x25519, AesGcm? aesGcm, Hkdf? hkdf})
    : _x25519 = x25519 ?? X25519(),
      _aesGcm = aesGcm ?? AesGcm.with256bits(),
      _hkdf = hkdf ?? Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  final X25519 _x25519;
  final AesGcm _aesGcm;
  final Hkdf _hkdf;

  Future<WrappedCoupleKey> wrap({
    required String keyId,
    required SecretKey coupleKey,
    required SimplePublicKey recipientPublicKey,
  }) async {
    final ephemeralKeyPair = await _x25519.newKeyPair();

    try {
      final sharedSecret = await _x25519.sharedSecretKey(
        keyPair: ephemeralKeyPair,
        remotePublicKey: recipientPublicKey,
      );

      final wrappingKey = await _deriveWrappingKey(sharedSecret);

      final nonce = _aesGcm.newNonce();

      final coupleKeyBytes = await coupleKey.extractBytes();

      final associatedData = _buildAssociatedData(
        keyId: keyId,
        encryptionVersion: 1,
      );

      final secretBox = await _aesGcm.encrypt(
        coupleKeyBytes,
        secretKey: wrappingKey,
        nonce: nonce,
        aad: associatedData,
      );

      final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();

      return WrappedCoupleKey(
        keyId: keyId,
        encryptionVersion: 1,
        ephemeralPublicKey: ephemeralPublicKey,
        nonce: secretBox.nonce,
        ciphertext: secretBox.cipherText,
        mac: secretBox.mac.bytes,
      );
    } finally {
      ephemeralKeyPair.destroy();
    }
  }

  Future<SecretKey> unwrap({
    required WrappedCoupleKey wrappedKey,
    required KeyPair recipientKeyPair,
  }) async {
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: recipientKeyPair,
      remotePublicKey: wrappedKey.ephemeralPublicKey,
    );

    final wrappingKey = await _deriveWrappingKey(sharedSecret);

    final secretBox = SecretBox(
      wrappedKey.ciphertext,
      nonce: wrappedKey.nonce,
      mac: Mac(wrappedKey.mac),
    );

    final associatedData = _buildAssociatedData(
      keyId: wrappedKey.keyId,
      encryptionVersion: wrappedKey.encryptionVersion,
    );

    final coupleKeyBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: wrappingKey,
      aad: associatedData,
    );

    return SecretKey(coupleKeyBytes);
  }

  Future<SecretKey> _deriveWrappingKey(SecretKey sharedSecret) {
    return _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: utf8.encode('couple-key-wrap-v1'),
    );
  }

  List<int> _buildAssociatedData({
    required String keyId,
    required int encryptionVersion,
  }) {
    return utf8.encode('$keyId:$encryptionVersion');
  }
}

class WrappedCoupleKey {
  const WrappedCoupleKey({
    required this.keyId,
    required this.encryptionVersion,
    required this.ephemeralPublicKey,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  final String keyId;
  final int encryptionVersion;
  final SimplePublicKey ephemeralPublicKey;
  final List<int> nonce;
  final List<int> ciphertext;
  final List<int> mac;

  Map<String, dynamic> toJson() {
    return {
      'key_id': keyId,
      'encryption_version': encryptionVersion,
      'ephemeral_public_key': base64Encode(ephemeralPublicKey.bytes),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(ciphertext),
      'mac': base64Encode(mac),
    };
  }

  factory WrappedCoupleKey.fromJson(Map<String, dynamic> json) {
    return WrappedCoupleKey(
      keyId: json['key_id'] as String,
      encryptionVersion: json['encryption_version'] as int,
      ephemeralPublicKey: SimplePublicKey(
        base64Decode(json['ephemeral_public_key'] as String),
        type: KeyPairType.x25519,
      ),
      nonce: base64Decode(json['nonce'] as String),
      ciphertext: base64Decode(json['ciphertext'] as String),
      mac: base64Decode(json['mac'] as String),
    );
  }
}
