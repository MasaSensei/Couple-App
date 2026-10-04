import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/security/couple/couple_key.dart';

void main() {
  test('stores key id and secret key', () async {
    final secretKey = SecretKeyData.random(length: 32);

    const keyId = 'test-key-id';

    final coupleKey = CoupleKey(keyId: keyId, secretKey: secretKey);

    expect(coupleKey.keyId, keyId);
    expect(coupleKey.secretKey, same(secretKey));
  });
}
