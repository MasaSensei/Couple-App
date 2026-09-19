import 'package:dio/dio.dart';

import '/features/auth/data/models/couple_model.dart';
import '../../../../core/error/api_error_handler.dart';
import '../../../../core/network/api_client.dart';

class CoupleRepository {
  const CoupleRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<CoupleModel> getCouple() async {
    try {
      final response = await apiClient.dio.get('/couple');

      final data = response.data['data'] as Map<String, dynamic>;
      final coupleData = data['couple'] as Map<String, dynamic>;

      return CoupleModel.fromJson(coupleData);
    } on DioException catch (error) {
      throw ApiErrorHandler.handle(error);
    }
  }

  Future<CoupleModel> createCouple() async {
    try {
      final response = await apiClient.dio.post('/couple');

      final data = response.data['data'] as Map<String, dynamic>;
      final coupleData = data['couple'] as Map<String, dynamic>;

      return CoupleModel.fromJson(coupleData);
    } on DioException catch (error) {
      throw ApiErrorHandler.handle(error);
    }
  }

  Future<CoupleModel> joinCouple({required String inviteCode}) async {
    try {
      final response = await apiClient.dio.post(
        '/couple/join',
        data: {'invite_code': inviteCode},
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final coupleData = data['couple'] as Map<String, dynamic>;

      return CoupleModel.fromJson(coupleData);
    } on DioException catch (error) {
      throw ApiErrorHandler.handle(error);
    }
  }
}
