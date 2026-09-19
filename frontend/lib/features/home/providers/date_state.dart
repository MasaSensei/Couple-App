import '../data/models/date_model.dart';

enum DateStatus { initial, loading, loaded, empty, error }

class DateState {
  const DateState({
    this.status = DateStatus.initial,
    this.dates = const [],
    this.errorMessage,
  });

  final DateStatus status;
  final List<DateModel> dates;
  final String? errorMessage;

  DateState copyWith({
    DateStatus? status,
    List<DateModel>? dates,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DateState(
      status: status ?? this.status,
      dates: dates ?? this.dates,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
