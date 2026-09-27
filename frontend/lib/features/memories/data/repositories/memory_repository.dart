import 'package:frontend/core/network/api_client.dart';

import '../models/memory_comment_model.dart';
import '../models/memory_model.dart';
import '../models/memory_photo_model.dart';
import '../models/memory_form_data.dart';

class MemoryRepository {
  MemoryRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<MemoryModel>> getMemories() async {
    final response = await _apiClient.get('/memories');

    final data = response.data['data'] as Map<String, dynamic>;

    final memories = data['memories'] as List<dynamic>;

    return memories
        .map((item) => MemoryModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<MemoryModel> getMemoryById(int memoryId) async {
    final response = await _apiClient.get('/memories/$memoryId');

    final data = response.data['data'] as Map<String, dynamic>;

    final memory = data['memory'] as Map<String, dynamic>;

    return MemoryModel.fromJson(memory);
  }

  Future<List<MemoryModel>> getTimeline({
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _apiClient.get(
      '/memories/timeline',
      queryParameters: {'page': page, 'per_page': perPage},
    );

    final data = response.data['data'] as Map<String, dynamic>;

    final memories = data['memories'] as List<dynamic>;

    return memories
        .map((item) => MemoryModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<MemoryModel> createMemory(MemoryFormData data) async {
    final response = await _apiClient.post('/memories', data: data.toJson());

    final responseData = response.data['data'] as Map<String, dynamic>;
    final memoryData = responseData['memory'] as Map<String, dynamic>;

    return MemoryModel.fromJson(memoryData);
  }

  Future<MemoryModel> updateMemory(int memoryId, MemoryFormData data) async {
    final response = await _apiClient.patch(
      '/memories/$memoryId',
      data: data.toJson(),
    );

    final responseData = response.data['data'] as Map<String, dynamic>;
    final memoryData = responseData['memory'] as Map<String, dynamic>;

    return MemoryModel.fromJson(memoryData);
  }

  Future<void> deleteMemory(int memoryId) async {
    await _apiClient.delete('/memories/$memoryId');
  }

  Future<List<MemoryPhotoModel>> getPhotos(int memoryId) async {
    final response = await _apiClient.get('/memories/$memoryId/photos');

    final data = response.data['data'] as Map<String, dynamic>;

    final photos = data['photos'] as List<dynamic>;

    return photos
        .map((item) => MemoryPhotoModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<MemoryCommentModel>> getComments(int memoryId) async {
    final response = await _apiClient.get('/memories/$memoryId/comments');

    final data = response.data['data'] as Map<String, dynamic>;

    final comments = data['comments'] as List<dynamic>;

    return comments
        .map(
          (item) => MemoryCommentModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<MemoryCommentModel> createComment({
    required int memoryId,
    required String body,
  }) async {
    final response = await _apiClient.post(
      '/memories/$memoryId/comments',
      data: {'body': body},
    );

    final data = response.data['data'] as Map<String, dynamic>;

    final comment = data['comment'] as Map<String, dynamic>;

    return MemoryCommentModel.fromJson(comment);
  }

  Future<MemoryCommentModel> updateComment({
    required int commentId,
    required String body,
  }) async {
    final response = await _apiClient.patch(
      '/memory-comments/$commentId',
      data: {'body': body},
    );

    final data = response.data['data'] as Map<String, dynamic>;

    final comment = data['comment'] as Map<String, dynamic>;

    return MemoryCommentModel.fromJson(comment);
  }

  Future<void> deleteComment(int commentId) async {
    await _apiClient.delete('/memory-comments/$commentId');
  }
}
