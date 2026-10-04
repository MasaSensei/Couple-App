import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/security/couple/couple_key_package.dart';

void main() {
  test('fromJson creates couple key package correctly', () {
    final package = CoupleKeyPackage.fromJson({
      'id': 1,
      'device_id': 2,
      'key_id': '550e8400-e29b-41d4-a716-446655440000',
      'encryption_version': 1,
      'ephemeral_public_key': 'public-key',
      'nonce': 'nonce',
      'ciphertext': 'ciphertext',
      'mac': 'mac',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:01:00Z',
      'revoked_at': null,
    });

    expect(package.id, 1);
    expect(package.deviceId, 2);
    expect(package.keyId, '550e8400-e29b-41d4-a716-446655440000');
    expect(package.encryptionVersion, 1);
    expect(package.ephemeralPublicKey, 'public-key');
    expect(package.nonce, 'nonce');
    expect(package.ciphertext, 'ciphertext');
    expect(package.mac, 'mac');
    expect(package.createdAt, isNotNull);
    expect(package.updatedAt, isNotNull);
    expect(package.revokedAt, isNull);
  });
}
