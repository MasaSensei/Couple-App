import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/error/api_exception.dart';
import 'package:frontend/features/home/data/models/date_comment_model.dart';

import '../../auth/providers/auth_dependencies.dart';
import '../data/repositories/date_repository.dart';
import 'date_notifier.dart';
import 'date_state.dart';
import 'date_comment_state.dart';

final dateRepositoryProvider = Provider<DateRepository>((ref) {
  return DateRepository(ref.watch(apiClientProvider));
});

final dateNotifierProvider = NotifierProvider<DateNotifier, DateState>(
  DateNotifier.new,
);

final dateCommentNotifierProvider =
    NotifierProvider<DateCommentNotifier, DateCommentState>(
      DateCommentNotifier.new,
    );

class DateCommentNotifier extends Notifier<DateCommentState> {
  DateRepository get _repository => ref.read(dateRepositoryProvider);

  @override
  DateCommentState build() {
    return const DateCommentState();
  }

  Future<void> loadComments(int dateId) async {
    state = state.copyWith(status: DateCommentStatus.loading, clearError: true);

    try {
      final comments = await _repository.getComments(dateId);

      if (comments.isEmpty) {
        state = const DateCommentState(status: DateCommentStatus.empty);
        return;
      }

      state = DateCommentState(
        status: DateCommentStatus.loaded,
        comments: comments,
      );
    } on ApiException catch (error) {
      state = DateCommentState(
        status: DateCommentStatus.error,
        errorMessage: error.message,
      );
    } catch (error) {
      state = DateCommentState(
        status: DateCommentStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<DateCommentModel?> createComment({
    required int dateId,
    required String content,
  }) async {
    try {
      final comment = await _repository.createComment(
        dateId: dateId,
        content: content,
      );

      state = state.copyWith(
        status: DateCommentStatus.loaded,
        comments: [...state.comments, comment],
        clearError: true,
      );

      return comment;
    } on ApiException catch (error) {
      state = state.copyWith(
        status: DateCommentStatus.error,
        errorMessage: error.message,
      );

      return null;
    } catch (error) {
      state = state.copyWith(
        status: DateCommentStatus.error,
        errorMessage: error.toString(),
      );

      return null;
    }
  }
}
