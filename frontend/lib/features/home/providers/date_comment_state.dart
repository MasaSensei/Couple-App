import '../data/models/date_comment_model.dart';

enum DateCommentStatus { initial, loading, loaded, empty, error }

class DateCommentState {
  const DateCommentState({
    this.status = DateCommentStatus.initial,
    this.comments = const [],
    this.errorMessage,
  });

  final DateCommentStatus status;
  final List<DateCommentModel> comments;
  final String? errorMessage;

  DateCommentState copyWith({
    DateCommentStatus? status,
    List<DateCommentModel>? comments,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DateCommentState(
      status: status ?? this.status,
      comments: comments ?? this.comments,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
