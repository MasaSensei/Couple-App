import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/security/couple/couple_key_package.dart';

void main() {
  test('couple key package response can be parsed', () {
    final response = {
      'data': {
        'packages': [
          {
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
          },
        ],
      },
    };

    final data = response['data'];

    expect(data, isA<Map<String, dynamic>>());

    final packages = (data as Map<String, dynamic>)['packages'];

    expect(packages, isA<List>());

    final result = (packages as List)
        .whereType<Map<String, dynamic>>()
        .map(CoupleKeyPackage.fromJson)
        .toList();

    expect(result, hasLength(1));
    expect(result.first.id, 1);
    expect(result.first.deviceId, 2);
  });
}
