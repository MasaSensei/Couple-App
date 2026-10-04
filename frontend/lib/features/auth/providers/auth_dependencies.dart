import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/device/services/device_registration_service.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../data/repositories/auth_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(apiClient: ref.watch(apiClientProvider));
});

final deviceRegistrationServiceProvider = Provider<DeviceRegistrationService>((
  ref,
) {
  return DeviceRegistrationService();
});
