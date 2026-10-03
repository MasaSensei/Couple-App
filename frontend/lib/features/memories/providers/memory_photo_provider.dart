import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/auth/providers/auth_dependencies.dart';
import 'package:frontend/features/memories/data/models/memory_photo_model.dart';
import 'package:frontend/features/memories/data/repositories/memory_photo_repository.dart';
import 'package:image_picker/image_picker.dart';

final memoryPhotoRepositoryProvider = Provider<MemoryPhotoRepository>((ref) {
  return MemoryPhotoRepository(ref.watch(apiClientProvider));
});

final memoryPhotoNotifierProvider =
    NotifierProvider<MemoryPhotoNotifier, AsyncValue<List<MemoryPhotoModel>>>(
      MemoryPhotoNotifier.new,
    );

class MemoryPhotoNotifier extends Notifier<AsyncValue<List<MemoryPhotoModel>>> {
  late final MemoryPhotoRepository _repository;

  final ImagePicker _picker = ImagePicker();

  @override
  AsyncValue<List<MemoryPhotoModel>> build() {
    _repository = ref.watch(memoryPhotoRepositoryProvider);

    return const AsyncData([]);
  }

  Future<void> loadPhotos({required int memoryId}) async {
    state = const AsyncLoading();

    try {
      final photos = await _repository.getPhotos(memoryId: memoryId);

      state = AsyncData(photos);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> pickAndUpload({required int memoryId}) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      return;
    }

    await uploadPhoto(memoryId: memoryId, file: File(pickedFile.path));
  }

  Future<void> uploadPhoto({required int memoryId, required File file}) async {
    state = const AsyncLoading();

    try {
      final bytes = await file.length();

      final photo = await _repository.createUploadSession(
        memoryId: memoryId,
        originalFilename: file.uri.pathSegments.last,
        mimeType: _mimeTypeFromPath(file.path),
        fileSize: bytes,
      );

      final uploadedPhoto = await _repository.uploadBinary(
        photoId: photo.id,
        file: file,
      );

      await _repository.completeUpload(photoId: uploadedPhoto.id);

      await loadPhotos(memoryId: memoryId);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> deletePhoto({
    required int memoryId,
    required int photoId,
  }) async {
    try {
      await _repository.deletePhoto(photoId: photoId);

      await loadPhotos(memoryId: memoryId);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  String _mimeTypeFromPath(String path) {
    final extension = path.split('.').last.toLowerCase();

    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';

      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      default:
        return 'application/octet-stream';
    }
  }
}
