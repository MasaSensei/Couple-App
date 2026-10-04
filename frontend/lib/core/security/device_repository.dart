import '../network/api_client.dart';

class DeviceRepository {
  DeviceRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> register({
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
        'device_name': ?deviceName,
      },
    );

    return response.data['data'] as Map<String, dynamic>;
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
}
