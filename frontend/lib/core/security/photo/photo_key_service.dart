import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../couple/couple_key.dart';

class PhotoKeyService {
  PhotoKeyService({Hkdf? hkdf})
    : _hkdf = hkdf ?? Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  final Hkdf _hkdf;

  Future<SecretKey> deriveKey({
    required CoupleKey coupleKey,
    required String photoId,
  }) {
    return _hkdf.deriveKey(
      secretKey: coupleKey.secretKey,
      nonce: utf8.encode('photo-key-v1:$photoId'),
    );
  }
}
