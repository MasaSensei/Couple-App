import 'package:frontend/features/auth/data/models/couple_model.dart';

import '../../../../core/network/api_client.dart';
import '../models/couple_invitation_model.dart';

class CoupleInvitationRepository {
  CoupleInvitationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<CoupleInvitationModel> createInvitation() async {
    final response = await _apiClient.post('/couple/invite');

    final data = response.data['data'] as Map<String, dynamic>;

    final invitationData = data['invitation'] as Map<String, dynamic>;

    return CoupleInvitationModel.fromJson(invitationData);
  }

  Future<CoupleInvitationModel> getInvitation(String token) async {
    final response = await _apiClient.get('/couple/invite/$token');

    final data = response.data['data'] as Map<String, dynamic>;

    final invitationData = data['invitation'] as Map<String, dynamic>;

    return CoupleInvitationModel.fromJson(invitationData);
  }

  Future<CoupleModel> acceptInvitation(String token) async {
    final response = await _apiClient.post('/couple/invite/$token/accept');

    final data = response.data['data'] as Map<String, dynamic>;

    final coupleData = data['couple'] as Map<String, dynamic>;

    return CoupleModel.fromJson(coupleData);
  }
}
