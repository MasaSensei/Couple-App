import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/repositories/memory_repository.dart';
import '../data/models/memory_model.dart';
import '../data/models/memory_form_data.dart';
import 'memory_providers.dart';
import 'memory_state.dart';

class MemoryNotifier extends Notifier<MemoryState> {
  MemoryRepository get _repository => ref.read(memoryRepositoryProvider);

  @override
  MemoryState build() {
    return const MemoryState();
  }

  Future<void> loadMemories() async {
    state = state.copyWith(status: MemoryStatus.loading, clearError: true);

    try {
      final memories = await _repository.getMemories();

      if (memories.isEmpty) {
        state = const MemoryState(status: MemoryStatus.empty);
        return;
      }

      state = MemoryState(status: MemoryStatus.loaded, memories: memories);
    } on ApiException catch (error) {
      state = MemoryState(
        status: MemoryStatus.error,
        errorMessage: error.message,
      );
    } catch (error) {
      state = MemoryState(
        status: MemoryStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> loadTimeline({int page = 1, int perPage = 20}) async {
    final isFirstPage = page == 1;

    state = state.copyWith(status: MemoryStatus.loading, clearError: true);

    try {
      final memories = await _repository.getTimeline(
        page: page,
        perPage: perPage,
      );

      final allMemories = isFirstPage
          ? memories
          : [...state.memories, ...memories];

      state = MemoryState(
        status: allMemories.isEmpty ? MemoryStatus.empty : MemoryStatus.loaded,
        memories: allMemories,
        currentPage: page,
        hasMore: memories.length >= perPage,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        status: MemoryStatus.error,
        errorMessage: error.message,
      );
    } catch (error) {
      state = state.copyWith(
        status: MemoryStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<MemoryModel?> createMemory(MemoryFormData data) async {
    state = state.copyWith(status: MemoryStatus.loading, clearError: true);

    try {
      final memory = await _repository.createMemory(data);

      state = state.copyWith(
        status: MemoryStatus.loaded,
        memories: [memory, ...state.memories],
      );

      return memory;
    } on ApiException catch (e) {
      state = state.copyWith(
        status: MemoryStatus.error,
        errorMessage: e.message,
      );

      return null;
    } catch (_) {
      state = state.copyWith(
        status: MemoryStatus.error,
        errorMessage: 'Something went wrong.',
      );

      return null;
    }
  }

  Future<MemoryModel?> updateMemory(int memoryId, MemoryFormData data) async {
    state = state.copyWith(status: MemoryStatus.loading, clearError: true);

    try {
      final memory = await _repository.updateMemory(memoryId, data);

      final updatedMemories = state.memories.map((item) {
        return item.id == memory.id ? memory : item;
      }).toList();

      state = state.copyWith(
        status: MemoryStatus.loaded,
        memories: updatedMemories,
      );

      return memory;
    } on ApiException catch (e) {
      state = state.copyWith(
        status: MemoryStatus.error,
        errorMessage: e.message,
      );

      return null;
    } catch (_) {
      state = state.copyWith(
        status: MemoryStatus.error,
        errorMessage: 'Something went wrong.',
      );

      return null;
    }
  }

  Future<bool> deleteMemory(int memoryId) async {
    try {
      await _repository.deleteMemory(memoryId);

      await loadMemories();

      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        status: MemoryStatus.error,
        errorMessage: error.message,
      );

      return false;
    } catch (error) {
      state = state.copyWith(
        status: MemoryStatus.error,
        errorMessage: error.toString(),
      );

      return false;
    }
  }
}
