import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/auth/providers/auth_dependencies.dart';
import 'package:frontend/features/memories/data/models/memory_comment_model.dart';
import 'package:frontend/features/memories/data/repositories/memory_repository.dart';

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepository(ref.watch(apiClientProvider));
});

final memoryCommentNotifierProvider =
    NotifierProvider<
      MemoryCommentNotifier,
      AsyncValue<List<MemoryCommentModel>>
    >(MemoryCommentNotifier.new);

class MemoryCommentNotifier
    extends Notifier<AsyncValue<List<MemoryCommentModel>>> {
  late final MemoryRepository _repository;

  @override
  AsyncValue<List<MemoryCommentModel>> build() {
    _repository = ref.watch(memoryRepositoryProvider);
    return const AsyncData([]);
  }

  Future<void> loadComments({required int memoryId}) async {
    state = const AsyncLoading();

    try {
      final comments = await _repository.getComments(memoryId);

      state = AsyncData(comments);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<bool> createComment({
    required int memoryId,
    required String body,
  }) async {
    try {
      final comment = await _repository.createComment(
        memoryId: memoryId,
        body: body,
      );

      final currentComments = state.value ?? [];

      state = AsyncData([...currentComments, comment]);

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateComment({
    required int commentId,
    required String body,
  }) async {
    try {
      final updatedComment = await _repository.updateComment(
        commentId: commentId,
        body: body,
      );

      final currentComments = state.value ?? [];

      state = AsyncData(
        currentComments.map((comment) {
          if (comment.id == commentId) {
            return updatedComment;
          }

          return comment;
        }).toList(),
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteComment({required int commentId}) async {
    try {
      await _repository.deleteComment(commentId);

      final currentComments = state.value ?? [];

      state = AsyncData(
        currentComments.where((comment) => comment.id != commentId).toList(),
      );

      return true;
    } catch (_) {
      return false;
    }
  }
}
