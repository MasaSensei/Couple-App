import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_storage.dart';
import '../data/repositories/auth_repository.dart';
import 'auth_dependencies.dart';
import 'auth_state.dart';

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _authRepository;
  late final TokenStorage _tokenStorage;

  @override
  AuthState build() {
    _authRepository = ref.watch(authRepositoryProvider);
    _tokenStorage = ref.watch(tokenStorageProvider);

    return const AuthState.initial();
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthState.loading();

    try {
      final response = await _authRepository.login(
        email: email,
        password: password,
      );

      await _tokenStorage.saveToken(response.token);

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

      await _tokenStorage.saveToken(response.token);

      state = AuthState.authenticated(response.user);
    } catch (error) {
      state = AuthState.error(error.toString());
    }
  }

  Future<void> checkAuth() async {
    state = const AuthState.loading();

    try {
      final token = await _tokenStorage.getToken();

      if (token == null || token.isEmpty) {
        state = const AuthState.unauthenticated();
        return;
      }

      final user = await _authRepository.me();

      state = AuthState.authenticated(user);
    } catch (error) {
      await _tokenStorage.deleteToken();

      state = const AuthState.unauthenticated();
    }
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
