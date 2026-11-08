import 'user_model.dart';

class AuthResponseModel {
  const AuthResponseModel({
    required this.token,
    required this.user,
    this.tokenExpiresAt,
  });

  final String token;
  final UserModel user;
  final DateTime? tokenExpiresAt;

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      token: json['token'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      tokenExpiresAt: parseExpiry(json['token_expires_at']),
    );
  }

  static DateTime? parseExpiry(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

/// Result of `POST /auth/refresh`.
class AuthTokenModel {
  const AuthTokenModel({required this.token, this.expiresAt});

  final String token;
  final DateTime? expiresAt;

  factory AuthTokenModel.fromJson(Map<String, dynamic> json) {
    return AuthTokenModel(
      token: json['token'] as String,
      expiresAt: AuthResponseModel.parseExpiry(json['token_expires_at']),
    );
  }
}
