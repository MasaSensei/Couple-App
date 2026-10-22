import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import 'couple_device.dart';
import 'couple_key_package.dart';

class CoupleKeyPackageRepository {
  CoupleKeyPackageRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<CoupleKeyPackage>> getKeyPackages() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/couple/key-packages',
    );

    final data = response.data?['data'];

    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid couple key packages response.');
    }

    final packages = data['packages'];

    if (packages is! List) {
      throw const FormatException('Invalid couple key packages list.');
    }

    return packages
        .whereType<Map<String, dynamic>>()
        .map(CoupleKeyPackage.fromJson)
        .toList();
  }

  Future<void> createKeyPackage({
    required int deviceId,
    required String keyId,
    required int encryptionVersion,
    required String ephemeralPublicKey,
    required String nonce,
    required String ciphertext,
    required String mac,
  }) async {
    await _apiClient.post(
      '/couple/key-packages',
      data: {
        'device_id': deviceId,
        'key_id': keyId,
        'encryption_version': encryptionVersion,
        'ephemeral_public_key': ephemeralPublicKey,
        'nonce': nonce,
        'ciphertext': ciphertext,
        'mac': mac,
      },
    );
  }

  Future<List<CoupleDevice>> getCoupleDevices() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/couple/devices',
    );

    final devices = response.data?['data']?['devices'];

    if (devices is! List) {
      throw const FormatException('Invalid couple devices response.');
    }

    return devices
        .whereType<Map<String, dynamic>>()
        .map(CoupleDevice.fromJson)
        .toList();
  }

  /// Returns null when the user has not set up a Recovery Key yet.
  Future<Map<String, dynamic>?> getRecoveryPackage() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/couple/recovery-package',
      );

      final package = response.data?['data']?['package'];

      if (package is! Map<String, dynamic>) {
        throw const FormatException('Invalid recovery package response.');
      }

      return package;
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  /// [payload] is already encrypted with the Recovery Key on this device.
  Future<void> putRecoveryPackage(Map<String, dynamic> payload) async {
    await _apiClient.put('/couple/recovery-package', data: payload);
  }
}
