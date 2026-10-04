import '../../../core/network/api_client.dart';
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
}
