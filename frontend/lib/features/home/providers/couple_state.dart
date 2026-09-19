import 'package:frontend/features/auth/data/models/couple_model.dart';

enum CoupleStatus { initial, loading, loaded, empty, error }

class CoupleState {
  const CoupleState({required this.status, this.couple, this.message});

  const CoupleState.initial()
    : status = CoupleStatus.initial,
      couple = null,
      message = null;

  const CoupleState.loading()
    : status = CoupleStatus.loading,
      couple = null,
      message = null;

  const CoupleState.loaded(this.couple)
    : status = CoupleStatus.loaded,
      message = null;

  const CoupleState.empty()
    : status = CoupleStatus.empty,
      couple = null,
      message = null;

  const CoupleState.error(this.message)
    : status = CoupleStatus.error,
      couple = null;

  final CoupleStatus status;
  final CoupleModel? couple;
  final String? message;
}
