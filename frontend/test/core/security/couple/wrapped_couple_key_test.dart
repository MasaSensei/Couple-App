import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/security/couple/couple_key_wrapper.dart';

void main() {
  test('serializes and deserializes wrapped couple key', () async {
    final original = WrappedCoupleKey(
      keyId: 'test-key-id',
      encryptionVersion: 1,
      ephemeralPublicKey: SimplePublicKey(
        List<int>.filled(32, 1),
        type: KeyPairType.x25519,
      ),
      nonce: List<int>.filled(12, 2),
      ciphertext: List<int>.filled(32, 3),
      mac: List<int>.filled(16, 4),
    );

    final json = original.toJson();

    final restored = WrappedCoupleKey.fromJson(json);

    expect(
      restored.ephemeralPublicKey.bytes,
      original.ephemeralPublicKey.bytes,
    );

    expect(restored.nonce, original.nonce);

    expect(restored.ciphertext, original.ciphertext);

    expect(restored.mac, original.mac);
  });
}
