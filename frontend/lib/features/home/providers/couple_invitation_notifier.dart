import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/home/providers/couple_invitation_providers.dart';

import '../../../core/error/api_exception.dart';
import '../data/repositories/couple_invitation_repository.dart';
import 'couple_invitation_state.dart';

class CoupleInvitationNotifier extends Notifier<CoupleInvitationState> {
  CoupleInvitationRepository get _repository =>
      ref.read(coupleInvitationRepositoryProvider);

  @override
  CoupleInvitationState build() {
    return const CoupleInvitationState();
  }

  Future<void> createInvitation() async {
    state = state.copyWith(
      status: CoupleInvitationStatus.loading,
      clearError: true,
    );

    try {
      final invitation = await _repository.createInvitation();

      state = CoupleInvitationState(
        status: CoupleInvitationStatus.created,
        invitation: invitation,
      );
    } on ApiException catch (error) {
      state = CoupleInvitationState(
        status: CoupleInvitationStatus.error,
        errorMessage: error.message,
      );
    } catch (error) {
      state = CoupleInvitationState(
        status: CoupleInvitationStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> loadInvitation(String token) async {
    state = state.copyWith(
      status: CoupleInvitationStatus.loading,
      clearError: true,
    );

    try {
      final invitation = await _repository.getInvitation(token);

      state = CoupleInvitationState(
        status: CoupleInvitationStatus.loaded,
        invitation: invitation,
      );
    } on ApiException catch (error) {
      state = CoupleInvitationState(
        status: CoupleInvitationStatus.error,
        errorMessage: error.message,
      );
    } catch (error) {
      state = CoupleInvitationState(
        status: CoupleInvitationStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> acceptInvitation(String token) async {
    state = state.copyWith(
      status: CoupleInvitationStatus.loading,
      clearError: true,
    );

    try {
      final couple = await _repository.acceptInvitation(token);

      state = CoupleInvitationState(
        status: CoupleInvitationStatus.accepted,
        couple: couple,
      );
    } on ApiException catch (error) {
      state = CoupleInvitationState(
        status: CoupleInvitationStatus.error,
        errorMessage: error.message,
      );
    } catch (error) {
      state = CoupleInvitationState(
        status: CoupleInvitationStatus.error,
        errorMessage: error.toString(),
      );
    }
  }
}
