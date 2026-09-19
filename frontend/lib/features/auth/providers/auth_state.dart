import '../data/models/user_model.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  const AuthState({required this.status, this.user, this.message});

  const AuthState.initial()
    : status = AuthStatus.initial,
      user = null,
      message = null;

  const AuthState.loading()
    : status = AuthStatus.loading,
      user = null,
      message = null;

  const AuthState.authenticated(this.user)
    : status = AuthStatus.authenticated,
      message = null;

  const AuthState.unauthenticated()
    : status = AuthStatus.unauthenticated,
      user = null,
      message = null;

  const AuthState.error(this.message) : status = AuthStatus.error, user = null;

  final AuthStatus status;
  final UserModel? user;
  final String? message;
}
