import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/home/data/models/date_model.dart';

import '../../../core/error/api_exception.dart';
import '../data/repositories/date_repository.dart';
import 'date_providers.dart';
import 'date_state.dart';

class DateNotifier extends Notifier<DateState> {
  DateRepository get _repository => ref.read(dateRepositoryProvider);

  @override
  DateState build() {
    return const DateState();
  }

  Future<void> loadDates() async {
    state = state.copyWith(status: DateStatus.loading, clearError: true);

    try {
      final dates = await _repository.getDates();

      if (dates.isEmpty) {
        state = const DateState(status: DateStatus.empty);

        return;
      }

      state = DateState(status: DateStatus.loaded, dates: dates);
    } on ApiException catch (error) {
      state = DateState(status: DateStatus.error, errorMessage: error.message);
    } catch (error) {
      state = DateState(
        status: DateStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<DateModel?> createDate({
    required String title,
    String? description,
    String? location,
    required DateTime scheduledAt,
  }) async {
    state = state.copyWith(status: DateStatus.loading, clearError: true);

    try {
      final date = await _repository.createDate(
        title: title,
        description: description,
        location: location,
        scheduledAt: scheduledAt,
      );

      await loadDates();

      return date;
    } on ApiException catch (error) {
      state = state.copyWith(
        status: DateStatus.error,
        errorMessage: error.message,
      );

      return null;
    } catch (error) {
      state = state.copyWith(
        status: DateStatus.error,
        errorMessage: error.toString(),
      );

      return null;
    }
  }

  Future<DateModel?> updateDate({
    required int dateId,
    required String title,
    String? description,
    String? location,
    required DateTime scheduledAt,
  }) async {
    state = state.copyWith(status: DateStatus.loading, clearError: true);

    try {
      final date = await _repository.updateDate(
        dateId: dateId,
        title: title,
        description: description,
        location: location,
        scheduledAt: scheduledAt,
      );

      await loadDates();

      return date;
    } on ApiException catch (error) {
      state = state.copyWith(
        status: DateStatus.error,
        errorMessage: error.message,
      );

      return null;
    } catch (error) {
      state = state.copyWith(
        status: DateStatus.error,
        errorMessage: error.toString(),
      );

      return null;
    }
  }

  Future<DateModel?> completeDate(int dateId) async {
    try {
      final date = await _repository.completeDate(dateId);

      return date;
    } on ApiException catch (error) {
      state = state.copyWith(
        status: DateStatus.error,
        errorMessage: error.message,
      );

      return null;
    } catch (error) {
      state = state.copyWith(
        status: DateStatus.error,
        errorMessage: error.toString(),
      );

      return null;
    }
  }

  Future<DateModel?> cancelDate(int dateId) async {
    try {
      final date = await _repository.cancelDate(dateId);

      return date;
    } on ApiException catch (error) {
      state = state.copyWith(
        status: DateStatus.error,
        errorMessage: error.message,
      );

      return null;
    } catch (error) {
      state = state.copyWith(
        status: DateStatus.error,
        errorMessage: error.toString(),
      );

      return null;
    }
  }
}
