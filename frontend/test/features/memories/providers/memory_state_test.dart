import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/memories/providers/memory_state.dart';

void main() {
  test('MemoryState has correct initial state', () {
    const state = MemoryState();

    expect(state.status, MemoryStatus.initial);

    expect(state.memories, isEmpty);
    expect(state.errorMessage, isNull);
    expect(state.currentPage, 1);
    expect(state.hasMore, true);
  });

  test('MemoryState copyWith updates values', () {
    const state = MemoryState();

    final updated = state.copyWith(
      status: MemoryStatus.loading,
      currentPage: 2,
      hasMore: false,
    );

    expect(updated.status, MemoryStatus.loading);

    expect(updated.currentPage, 2);
    expect(updated.hasMore, false);
  });
}
