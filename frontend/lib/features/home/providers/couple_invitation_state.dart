import 'package:frontend/features/auth/data/models/couple_model.dart';

import '../data/models/couple_invitation_model.dart';

enum CoupleInvitationStatus {
  initial,
  loading,
  created,
  loaded,
  accepted,
  error,
}

class CoupleInvitationState {
  const CoupleInvitationState({
    this.status = CoupleInvitationStatus.initial,
    this.invitation,
    this.couple,
    this.errorMessage,
  });

  final CoupleInvitationStatus status;
  final CoupleInvitationModel? invitation;
  final CoupleModel? couple;
  final String? errorMessage;

  CoupleInvitationState copyWith({
    CoupleInvitationStatus? status,
    CoupleInvitationModel? invitation,
    CoupleModel? couple,
    String? errorMessage,
    bool clearInvitation = false,
    bool clearCouple = false,
    bool clearError = false,
  }) {
    return CoupleInvitationState(
      status: status ?? this.status,
      invitation: clearInvitation ? null : (invitation ?? this.invitation),
      couple: clearCouple ? null : (couple ?? this.couple),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
