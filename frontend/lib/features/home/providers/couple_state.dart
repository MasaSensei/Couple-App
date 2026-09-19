import 'package:frontend/features/auth/data/models/couple_model.dart';

enum CoupleStatus { initial, loading, loaded, empty, error }

class CoupleState {
  const CoupleState({
    this.status = CoupleStatus.initial,
    this.couple,
    this.errorMessage,
  });

  final CoupleStatus status;
  final CoupleModel? couple;
  final String? errorMessage;

  CoupleState copyWith({
    CoupleStatus? status,
    CoupleModel? couple,
    String? errorMessage,
    bool clearCouple = false,
    bool clearError = false,
  }) {
    return CoupleState(
      status: status ?? this.status,
      couple: clearCouple ? null : (couple ?? this.couple),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
