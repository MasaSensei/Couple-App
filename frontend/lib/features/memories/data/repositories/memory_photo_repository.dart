import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/core/network/api_client.dart';

import '../models/memory_photo_model.dart';

import 'package:frontend/core/security/couple/couple_key.dart';
import 'package:frontend/core/security/photo/photo_encryption_service.dart';
import 'package:frontend/core/security/photo/photo_encryption_metadata.dart';

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
    int? encryptionVersion,
    String? encryptionAlgorithm,
    String? keyId,
    String? nonce,
    int? encryptedSize,
    String? checksum,
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
        'encryption_version': ?encryptionVersion,
        'encryption_algorithm': ?encryptionAlgorithm,
        'key_id': ?keyId,
        'nonce': ?nonce,
        'encrypted_size': ?encryptedSize,
        'checksum': ?checksum,
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

  Future<List<int>> getDecryptedPhotoBytes({
    required MemoryPhotoModel photo,
    required CoupleKey coupleKey,
    required PhotoEncryptionService encryptionService,
  }) async {
    if (photo.encryptionVersion == null ||
        photo.encryptionAlgorithm != 'AES-256-GCM' ||
        photo.keyId == null ||
        photo.nonce == null ||
        photo.mac == null ||
        photo.checksum == null) {
      throw StateError('Photo encryption metadata is incomplete.');
    }

    if (photo.keyId != coupleKey.keyId) {
      throw StateError('Photo key ID does not match the available Couple Key.');
    }

    if (photo.encryptionVersion != PhotoEncryptionService.encryptionVersion) {
      throw UnsupportedError('Unsupported photo encryption version.');
    }

    final ciphertext = await getPhotoBytes(photoId: photo.id);

    if (photo.encryptedSize != null &&
        ciphertext.length != photo.encryptedSize) {
      throw StateError('Encrypted photo size mismatch.');
    }

    final encryptedPhoto = EncryptedPhoto(
      metadata: PhotoEncryptionMetadata(
        keyId: photo.keyId!,
        encryptionVersion: photo.encryptionVersion!,
      ),
      nonce: base64Decode(photo.nonce!),
      ciphertext: ciphertext,
      mac: base64Decode(photo.mac!),
      checksum: photo.checksum!,
    );

    return encryptionService.decrypt(
      encryptedPhoto: encryptedPhoto,
      coupleKey: coupleKey,
      photoId: photo.id.toString(),
    );
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

  Future<MemoryPhotoModel> uploadEncryptedBinary({
    required int photoId,
    required List<int> ciphertext,
    required String filename,
  }) async {
    debugPrint('Ciphertext size: ${ciphertext.length} bytes');
    debugPrint('Upload filename: $filename');

    final formData = FormData.fromMap({
      'encryption_mode': 'encrypted',
      'photo': MultipartFile.fromBytes(
        ciphertext,
        filename: filename,
        contentType: DioMediaType('application', 'octet-stream'),
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

  Future<MemoryPhotoModel> updateEncryptionMetadata({
    required int photoId,
    required int encryptionVersion,
    required String encryptionAlgorithm,
    required String keyId,
    required String nonce,
    required String mac,
    required int encryptedSize,
    required String checksum,
  }) async {
    final response = await _apiClient.dio.patch(
      '/memory-photos/$photoId/encryption',
      data: {
        'encryption_version': encryptionVersion,
        'encryption_algorithm': encryptionAlgorithm,
        'key_id': keyId,
        'nonce': nonce,
        'mac': mac,
        'encrypted_size': encryptedSize,
        'checksum': checksum,
      },
    );

    return MemoryPhotoModel.fromJson(
      response.data['data']['photo'] as Map<String, dynamic>,
    );
  }
}
