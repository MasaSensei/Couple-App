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

      final data = response.data['data'] as Map<String, dynamic>;

      return UserModel.fromJson(data);
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
