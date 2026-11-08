import 'package:dio/dio.dart';
import 'package:frontend/features/auth/data/models/user_model.dart';

import '../../../../core/error/api_error_handler.dart';
import '../../../../core/network/api_client.dart';
import '../models/auth_response_model.dart';

class AuthRepository {
  const AuthRepository({required this._apiClient});

  final ApiClient _apiClient;

  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );

      final data = response.data['data'] as Map<String, dynamic>;

      return AuthResponseModel.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorHandler.handle(error);
    }
  }

  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final data = response.data['data'] as Map<String, dynamic>;

      return AuthResponseModel.fromJson(data);
    } on DioException catch (error) {
      throw ApiErrorHandler.handle(error);
    }
  }

  Future<UserModel> me() async {
    try {
      final response = await _apiClient.dio.get('/me');

      // Backend shape: { data: { user: {...} } }
      final data = response.data['data'] as Map<String, dynamic>;

      return UserModel.fromJson(data['user'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ApiErrorHandler.handle(error);
    }
  }

  /// Exchanges the current token for a fresh one (the old one stops working).
  Future<AuthTokenModel> refreshToken() async {
    try {
      final response = await _apiClient.dio.post('/auth/refresh');
      return AuthTokenModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw ApiErrorHandler.handle(error);
    }
  }

  /// Permanently deletes the account. Requires the current password.
  /// Returns what happened to the couple space: none | kept_by_partner | dissolved.
  Future<String> deleteAccount({required String password}) async {
    try {
      final response = await _apiClient.dio.delete(
        '/me',
        data: {'password': password},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return data['couple'] as String;
    } on DioException catch (error) {
      throw ApiErrorHandler.handle(error);
    }
  }

  /// Machine-readable copy of the account's data (JSON).
  Future<Map<String, dynamic>> exportData() async {
    try {
      final response = await _apiClient.dio.get('/me/export');
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (error) {
      throw ApiErrorHandler.handle(error);
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post('/auth/logout');
    } on DioException catch (error) {
      throw ApiErrorHandler.handle(error);
    }
  }
}
