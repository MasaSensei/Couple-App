import 'dart:io';

import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

import '../models/memory_photo_model.dart';

class MemoryPhotoRepository {
  MemoryPhotoRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<MemoryPhotoModel> createUploadSession({
    required int memoryId,
    required String originalFilename,
    required String mimeType,
    required int fileSize,
    int? width,
    int? height,
    int sortOrder = 0,
  }) async {
    final response = await _apiClient.post(
      '/memories/$memoryId/photos/upload',
      data: {
        'original_filename': originalFilename,
        'mime_type': mimeType,
        'file_size': fileSize,
        'width': ?width,
        'height': ?height,
        'sort_order': sortOrder,
      },
    );

    final data = response.data['data'] as Map<String, dynamic>;
    final photo = data['photo'] as Map<String, dynamic>;

    return MemoryPhotoModel.fromJson(photo);
  }

  Future<List<int>> getPhotoBytes({required int photoId}) async {
    final response = await _apiClient.getBytes(
      '/memory-photos/$photoId/content',
    );

    return response.data ?? <int>[];
  }

  Future<MemoryPhotoModel> uploadBinary({
    required int photoId,
    required File file,
  }) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.last,
      ),
    });

    final response = await _apiClient.post(
      '/memory-photos/$photoId/upload',
      data: formData,
    );

    final data = response.data['data'] as Map<String, dynamic>;
    final photo = data['photo'] as Map<String, dynamic>;

    return MemoryPhotoModel.fromJson(photo);
  }

  Future<MemoryPhotoModel> completeUpload({required int photoId}) async {
    final response = await _apiClient.post('/memory-photos/$photoId/complete');

    final data = response.data['data'] as Map<String, dynamic>;
    final photo = data['photo'] as Map<String, dynamic>;

    return MemoryPhotoModel.fromJson(photo);
  }

  Future<void> deletePhoto({required int photoId}) async {
    await _apiClient.delete('/memory-photos/$photoId');
  }

  Future<List<MemoryPhotoModel>> getPhotos({required int memoryId}) async {
    final response = await _apiClient.get('/memories/$memoryId/photos');

    final data = response.data['data'] as Map<String, dynamic>;
    final photos = data['photos'] as List<dynamic>;

    return photos
        .map(
          (photo) => MemoryPhotoModel.fromJson(photo as Map<String, dynamic>),
        )
        .toList();
  }
}
