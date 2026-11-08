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

  /// Sets (or clears, with null) the couple's anniversary.
  Future<CoupleModel> updateRelationshipStart(DateTime? date) async {
    final response = await _apiClient.patch(
      '/couple',
      data: {
        'relationship_started_at': date == null
            ? null
            : '${date.year.toString().padLeft(4, '0')}-'
                  '${date.month.toString().padLeft(2, '0')}-'
                  '${date.day.toString().padLeft(2, '0')}',
      },
    );

    final data = response.data['data'] as Map<String, dynamic>;

    return CoupleModel.fromJson(data['couple'] as Map<String, dynamic>);
  }
}
