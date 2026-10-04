import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/device/data/models/device_model.dart';

class DeviceRepository {
  DeviceRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<void> registerDevice({
    required String deviceIdentifier,
    required String deviceName,
    required String platform,
    required String publicKey,
  }) async {
    await _apiClient.post(
      '/devices',
      data: {
        'device_identifier': deviceIdentifier,
        'device_name': deviceName,
        'platform': platform,
        'public_key': publicKey,
      },
    );
  }

  Future<List<DeviceModel>> getDevices() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/devices');

    final data = response.data?['data'];

    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid devices response.');
    }

    final devices = data['devices'];

    if (devices is! List) {
      throw const FormatException('Invalid devices list.');
    }

    return devices
        .whereType<Map<String, dynamic>>()
        .map(DeviceModel.fromJson)
        .toList();
  }

  Future<void> revokeDevice(int deviceId) async {
    await _apiClient.delete('/devices/$deviceId');
  }
}
