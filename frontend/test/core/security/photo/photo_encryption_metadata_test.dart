import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/security/photo/photo_encryption_metadata.dart';

void main() {
  test('metadata survives json serialization', () {
    const metadata = PhotoEncryptionMetadata(
      keyId: 'test-key',
      encryptionVersion: 1,
    );

    final json = metadata.toJson();

    final restored = PhotoEncryptionMetadata.fromJson(json);

    expect(restored.keyId, metadata.keyId);
    expect(restored.encryptionVersion, metadata.encryptionVersion);
  });
}
