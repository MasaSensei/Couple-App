import '/features/auth/data/models/couple_model.dart';

import '../../../../core/network/api_client.dart';

class CoupleRepository {
  CoupleRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<CoupleModel> getMyCouple() async {
    final response = await _apiClient.get('/couple');

    final data = response.data['data'] as Map<String, dynamic>;

    final coupleData = data['couple'] as Map<String, dynamic>;

    return CoupleModel.fromJson(coupleData);
  }

  Future<CoupleModel> createCouple() async {
    final response = await _apiClient.post('/couple');

    final data = response.data['data'] as Map<String, dynamic>;

    final coupleData = data['couple'] as Map<String, dynamic>;

    return CoupleModel.fromJson(coupleData);
  }

  Future<CoupleModel> joinCouple(String inviteCode) async {
    final response = await _apiClient.post(
      '/couple/join',
      data: {'invite_code': inviteCode},
    );

    final data = response.data['data'] as Map<String, dynamic>;

    final coupleData = data['couple'] as Map<String, dynamic>;

    return CoupleModel.fromJson(coupleData);
  }

  Future<CoupleModel> getCoupleById(int coupleId) async {
    final response = await _apiClient.get('/couple/$coupleId');

    final data = response.data['data'] as Map<String, dynamic>;

    final coupleData = data['couple'] as Map<String, dynamic>;

    return CoupleModel.fromJson(coupleData);
  }
}
