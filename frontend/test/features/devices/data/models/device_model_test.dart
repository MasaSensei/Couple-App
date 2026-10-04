import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/device/data/models/device_model.dart';

void main() {
  test('parses device json correctly', () {
    final model = DeviceModel.fromJson({
      'id': 1,
      'device_identifier': '550e8400-e29b-41d4-a716-446655440000',
      'device_name': 'My Phone',
      'platform': 'android',
      'public_key': 'test-public-key',
      'last_seen_at': '2026-09-30T10:00:00Z',
      'revoked_at': null,
      'created_at': '2026-09-30T09:00:00Z',
      'updated_at': '2026-09-30T10:00:00Z',
    });

    expect(model.id, 1);
    expect(model.deviceIdentifier, '550e8400-e29b-41d4-a716-446655440000');
    expect(model.deviceName, 'My Phone');
    expect(model.platform, 'android');
    expect(model.publicKey, 'test-public-key');
    expect(model.lastSeenAt, isNotNull);
    expect(model.revokedAt, isNull);
  });

  test('parses revoked device correctly', () {
    final model = DeviceModel.fromJson({
      'id': 2,
      'device_identifier': 'device-2',
      'device_name': 'Old Phone',
      'platform': 'android',
      'public_key': 'test-public-key',
      'last_seen_at': '2026-09-30T10:00:00Z',
      'revoked_at': '2026-09-30T11:00:00Z',
      'created_at': '2026-09-30T09:00:00Z',
      'updated_at': '2026-09-30T11:00:00Z',
    });

    expect(model.revokedAt, isNotNull);
  });
}
