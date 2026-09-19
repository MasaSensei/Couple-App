import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/repositories/couple_repository.dart';
import 'couple_providers.dart';
import 'couple_state.dart';

class CoupleNotifier extends Notifier<CoupleState> {
  CoupleRepository get _repository => ref.read(coupleRepositoryProvider);

  @override
  CoupleState build() {
    return const CoupleState();
  }

  Future<void> loadCouple() async {
    state = state.copyWith(status: CoupleStatus.loading, clearError: true);

    try {
      final couple = await _repository.getMyCouple();

      state = CoupleState(status: CoupleStatus.loaded, couple: couple);
    } on ApiException catch (error) {
      if (error.statusCode == 404 &&
          error.message == 'User does not belong to a couple.') {
        state = const CoupleState(status: CoupleStatus.empty);

        return;
      }

      state = CoupleState(
        status: CoupleStatus.error,
        errorMessage: error.message,
      );
    } catch (error) {
      state = CoupleState(
        status: CoupleStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> createCouple() async {
    state = state.copyWith(status: CoupleStatus.loading, clearError: true);

    try {
      final couple = await _repository.createCouple();

      state = CoupleState(status: CoupleStatus.loaded, couple: couple);
    } on ApiException catch (error) {
      state = CoupleState(
        status: CoupleStatus.error,
        errorMessage: error.message,
      );
    } catch (error) {
      state = CoupleState(
        status: CoupleStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> joinCouple(String inviteCode) async {
    state = state.copyWith(status: CoupleStatus.loading, clearError: true);

    try {
      final couple = await _repository.joinCouple(inviteCode);

      state = CoupleState(status: CoupleStatus.loaded, couple: couple);
    } on ApiException catch (error) {
      state = CoupleState(
        status: CoupleStatus.error,
        errorMessage: error.message,
      );
    } catch (error) {
      state = CoupleState(
        status: CoupleStatus.error,
        errorMessage: error.toString(),
      );
    }
  }
}
