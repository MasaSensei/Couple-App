import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../../device/services/device_registration_service.dart';
import '../data/repositories/auth_repository.dart';
import 'auth_dependencies.dart';
import 'auth_state.dart';

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _authRepository;
  late final TokenStorage _tokenStorage;
  late final DeviceRegistrationService _deviceRegistrationService;

  @override
  AuthState build() {
    _authRepository = ref.watch(authRepositoryProvider);
    _tokenStorage = ref.watch(tokenStorageProvider);
    _deviceRegistrationService = ref.watch(deviceRegistrationServiceProvider);

    return const AuthState.initial();
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthState.loading();

    try {
      final response = await _authRepository.login(
        email: email,
        password: password,
      );

      await _tokenStorage.saveToken(
        response.token,
        expiresAt: response.tokenExpiresAt,
      );

      await _deviceRegistrationService.registerCurrentDevice();

      state = AuthState.authenticated(response.user);
    } catch (error) {
      state = AuthState.error(error.toString());
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    state = const AuthState.loading();

    try {
      final response = await _authRepository.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );

      await _tokenStorage.saveToken(
        response.token,
        expiresAt: response.tokenExpiresAt,
      );

      await _deviceRegistrationService.registerCurrentDevice();

      state = AuthState.authenticated(response.user);
    } catch (error) {
      state = AuthState.error(error.toString());
    }
  }

  /// Rotate the token when it has less than this left (server TTL is 60 days).
  static const refreshWindow = Duration(days: 14);

  Future<void> checkAuth() async {
    state = const AuthState.loading();

    final token = await _tokenStorage.getToken();

    if (token == null || token.isEmpty) {
      state = const AuthState.unauthenticated();
      return;
    }

    try {
      final user = await _authRepository.me();
      await _refreshTokenIfDue();

      state = AuthState.authenticated(user);
    } on ApiException catch (error) {
      // Only an explicit 401 means the session is gone. Offline, timeouts and
      // server errors keep the token so the user is not logged out by a bad network.
      if (error.statusCode == 401) {
        await _tokenStorage.deleteToken();
        state = const AuthState.unauthenticated();
      } else {
        state = AuthState.error(error.message);
      }
    } catch (error, stackTrace) {
      // Network failures arrive as ApiException above; anything here is a
      // client-side bug (e.g. an unexpected response shape), not connectivity.
      debugPrint('checkAuth failed: $error\n$stackTrace');
      state = const AuthState.error(
        'Something went wrong while restoring your session. Please try again.',
      );
    }
  }

  Future<void> _refreshTokenIfDue() async {
    final expiresAt = await _tokenStorage.getExpiresAt();

    // Unknown expiry (token from an older app version) is refreshed too.
    if (expiresAt != null &&
        expiresAt.difference(DateTime.now()) > refreshWindow) {
      return;
    }

    try {
      final fresh = await _authRepository.refreshToken();
      await _tokenStorage.saveToken(fresh.token, expiresAt: fresh.expiresAt);
    } catch (_) {
      // Not fatal: the current token is still valid; retried on the next start.
    }
  }

  /// Deletes the account on the server, then clears every local credential.
  Future<String> deleteAccount({required String password}) async {
    final outcome = await _authRepository.deleteAccount(password: password);

    await _tokenStorage.deleteToken();
    state = const AuthState.unauthenticated();

    return outcome;
  }

  Future<void> logout() async {
    state = const AuthState.loading();

    try {
      await _authRepository.logout();
    } catch (_) {
      // Local authentication state must still be cleared
      // even if the server request fails.
    } finally {
      await _tokenStorage.deleteToken();

      state = const AuthState.unauthenticated();
    }
  }
}
