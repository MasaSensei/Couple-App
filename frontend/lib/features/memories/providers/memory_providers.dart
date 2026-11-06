import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/models/memory_protection_summary.dart';
import '../data/repositories/memory_repository.dart';
import 'memory_notifier.dart';
import 'memory_state.dart';

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepository(ApiClient());
});

final memoryNotifierProvider = NotifierProvider<MemoryNotifier, MemoryState>(
  MemoryNotifier.new,
);

/// Server-reported protection of the couple's photos. Refreshed on open.
final memoryProtectionProvider =
    FutureProvider.autoDispose<MemoryProtectionSummary>((ref) {
      return ref.watch(memoryRepositoryProvider).getProtection();
    });
