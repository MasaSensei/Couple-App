import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/home/providers/date_comment_state.dart';

void main() {
  group('DateCommentState', () {
    test('initial state is correct', () {
      const state = DateCommentState();

      expect(state.status, DateCommentStatus.initial);
      expect(state.comments, isEmpty);
      expect(state.errorMessage, isNull);
    });

    test('copyWith changes status', () {
      const state = DateCommentState();

      final updatedState = state.copyWith(status: DateCommentStatus.loading);

      expect(updatedState.status, DateCommentStatus.loading);

      expect(updatedState.comments, isEmpty);
      expect(updatedState.errorMessage, isNull);
    });

    test('copyWith changes comments', () {
      const state = DateCommentState();

      final updatedState = state.copyWith(status: DateCommentStatus.loaded);

      expect(updatedState.status, DateCommentStatus.loaded);
      expect(updatedState.comments, isEmpty);
    });

    test('copyWith sets error message', () {
      const state = DateCommentState();

      final updatedState = state.copyWith(
        status: DateCommentStatus.error,
        errorMessage: 'Unable to load comments.',
      );

      expect(updatedState.status, DateCommentStatus.error);
      expect(updatedState.errorMessage, 'Unable to load comments.');
    });

    test('copyWith clearError removes existing error', () {
      const state = DateCommentState(
        status: DateCommentStatus.error,
        errorMessage: 'Something went wrong.',
      );

      final updatedState = state.copyWith(
        status: DateCommentStatus.loading,
        clearError: true,
      );

      expect(updatedState.status, DateCommentStatus.loading);
      expect(updatedState.errorMessage, isNull);
    });
  });
}
