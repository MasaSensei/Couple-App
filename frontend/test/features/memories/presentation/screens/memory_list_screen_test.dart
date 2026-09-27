import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/memories/data/models/memory_model.dart';
import 'package:frontend/features/memories/presentation/screens/memory_list_screen.dart';
import 'package:frontend/features/memories/providers/memory_notifier.dart';
import 'package:frontend/features/memories/providers/memory_providers.dart';
import 'package:frontend/features/memories/providers/memory_state.dart';

void main() {
  testWidgets('MemoryListScreen renders loaded memories', (tester) async {
    final memory = MemoryModel(
      id: 1,
      coupleId: 1,
      createdBy: 1,
      title: 'Dinner Together',
      memoryDate: DateTime(2026, 9, 20),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryNotifierProvider.overrideWith(
            () => _FakeMemoryNotifier(
              MemoryState(
                status: MemoryStatus.loaded,
                memories: [memory],
                hasMore: false,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: MemoryListScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('Our Memories'), findsOneWidget);

    expect(find.text('Dinner Together'), findsOneWidget);

    expect(find.text('20 Sep 2026'), findsOneWidget);
  });

  testWidgets('MemoryListScreen renders empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoryNotifierProvider.overrideWith(
            () => _FakeMemoryNotifier(
              const MemoryState(status: MemoryStatus.empty),
            ),
          ),
        ],
        child: const MaterialApp(home: MemoryListScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('No memories yet'), findsOneWidget);
  });
}

class _FakeMemoryNotifier extends MemoryNotifier {
  _FakeMemoryNotifier(this.initialState);

  final MemoryState initialState;

  @override
  MemoryState build() {
    return initialState;
  }

  @override
  Future<void> loadTimeline({int page = 1, int perPage = 20}) async {
    // Do nothing.
    // Widget test tidak boleh melakukan API request.
  }
}
