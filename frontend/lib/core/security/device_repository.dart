import '../network/api_client.dart';

class DeviceRepository {
  DeviceRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> registerDevice({
    required String deviceIdentifier,
    required String platform,
    required String publicKey,
    String? deviceName,
  }) async {
    final response = await _apiClient.post(
      '/devices',
      data: {
        'device_identifier': deviceIdentifier,
        'platform': platform,
        'public_key': publicKey,
        'device_name': deviceName,
      },
    );

    final data = response.data['data'] as Map<String, dynamic>;
    return data['device'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getDevices() async {
    final response = await _apiClient.get('/devices');

    final data = response.data['data'] as Map<String, dynamic>;
    final devices = data['devices'] as List<dynamic>;

    return devices.map((device) => device as Map<String, dynamic>).toList();
  }

  Future<void> revoke({required int deviceId}) async {
    await _apiClient.delete('/devices/$deviceId');
  }

  Future<int> getRegisteredDeviceId({required String deviceIdentifier}) async {
    final response = await _apiClient.get('/devices');
    final data = response.data['data'] as Map<String, dynamic>;
    final devices = data['devices'] as List<dynamic>;

    for (final item in devices) {
      final device = item as Map<String, dynamic>;

      if (device['device_identifier'] == deviceIdentifier &&
          device['revoked_at'] == null) {
        final id = device['id'];

        if (id is int) return id;

        throw const FormatException('Invalid device ID.');
      }
    }

    throw StateError('Registered device was not found.');
  }
}
