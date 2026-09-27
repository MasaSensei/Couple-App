import '../data/models/memory_model.dart';

enum MemoryStatus { initial, loading, loaded, empty, error }

class MemoryState {
  const MemoryState({
    this.status = MemoryStatus.initial,
    this.memories = const [],
    this.errorMessage,
    this.currentPage = 1,
    this.hasMore = true,
  });

  final MemoryStatus status;
  final List<MemoryModel> memories;
  final String? errorMessage;

  final int currentPage;
  final bool hasMore;

  MemoryState copyWith({
    MemoryStatus? status,
    List<MemoryModel>? memories,
    String? errorMessage,
    int? currentPage,
    bool? hasMore,
    bool clearError = false,
  }) {
    return MemoryState(
      status: status ?? this.status,
      memories: memories ?? this.memories,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}
