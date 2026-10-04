import 'package:uuid/uuid.dart';

import 'device_key_storage.dart';

class DeviceIdentityService {
  DeviceIdentityService({DeviceKeyStorage? storage, Uuid? uuid})
    : _storage = storage ?? DeviceKeyStorage(),
      _uuid = uuid ?? const Uuid();

  final DeviceKeyStorage _storage;
  final Uuid _uuid;

  Future<String> getOrCreateDeviceId() async {
    final existingDeviceId = await _storage.readDeviceId();

    if (existingDeviceId != null && existingDeviceId.isNotEmpty) {
      return existingDeviceId;
    }

    final deviceId = _uuid.v4();

    await _storage.saveDeviceId(deviceId);

    return deviceId;
  }
}
