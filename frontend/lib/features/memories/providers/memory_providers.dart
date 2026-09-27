import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/repositories/memory_repository.dart';
import 'memory_notifier.dart';
import 'memory_state.dart';

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepository(ApiClient());
});

final memoryNotifierProvider = NotifierProvider<MemoryNotifier, MemoryState>(
  MemoryNotifier.new,
);
