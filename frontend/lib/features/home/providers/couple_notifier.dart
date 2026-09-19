import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/repositories/couple_repository.dart';
import 'couple_providers.dart';
import 'couple_state.dart';

class CoupleNotifier extends Notifier<CoupleState> {
  late final CoupleRepository _coupleRepository;

  @override
  CoupleState build() {
    _coupleRepository = ref.watch(coupleRepositoryProvider);

    return const CoupleState.initial();
  }

  Future<void> loadCouple() async {
    state = const CoupleState.loading();

    try {
      final couple = await _coupleRepository.getCouple();

      state = CoupleState.loaded(couple);
    } on ApiException catch (error) {
      if (error.message == 'User does not belong to a couple.') {
        state = const CoupleState.empty();
        return;
      }

      state = CoupleState.error(error.message);
    } catch (error) {
      state = CoupleState.error(error.toString());
    }
  }

  Future<void> createCouple() async {
    state = const CoupleState.loading();

    try {
      final couple = await _coupleRepository.createCouple();

      state = CoupleState.loaded(couple);
    } on ApiException catch (error) {
      state = CoupleState.error(error.message);
    } catch (error) {
      state = CoupleState.error(error.toString());
    }
  }

  Future<void> joinCouple({required String inviteCode}) async {
    state = const CoupleState.loading();

    try {
      final couple = await _coupleRepository.joinCouple(inviteCode: inviteCode);

      state = CoupleState.loaded(couple);
    } on ApiException catch (error) {
      state = CoupleState.error(error.message);
    } catch (error) {
      state = CoupleState.error(error.toString());
    }
  }
}
