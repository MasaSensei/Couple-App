import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/security/encryption_errors.dart';

import '../models/memory_photo_model.dart';

import 'package:frontend/core/security/couple/couple_key.dart';
import 'package:frontend/core/security/photo/photo_encryption_service.dart';
import 'package:frontend/core/security/photo/photo_encryption_metadata.dart';

class MemoryPhotoRepository {
  MemoryPhotoRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<MemoryPhotoModel> createUploadSession({
    required int memoryId,
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

  /// Downloads ciphertext and decrypts it locally. Throws
  /// [CoupleKeyUnavailableException] when [coupleKey] is not the photo's key and
  /// [PhotoVerificationException] when integrity or authentication fails.
  /// Unverified bytes are never returned.
  Future<List<int>> getDecryptedPhotoBytes({
    required MemoryPhotoModel photo,
    required CoupleKey coupleKey,
    required PhotoEncryptionService encryptionService,
  }) async {
    if (photo.encryptionVersion != PhotoEncryptionService.encryptionVersion ||
        photo.encryptionAlgorithm != 'AES-256-GCM' ||
        photo.keyId == null ||
        photo.nonce == null ||
        photo.mac == null ||
        photo.checksum == null) {
      throw const PhotoVerificationException();
    }

    if (photo.keyId != coupleKey.keyId) {
      throw const CoupleKeyUnavailableException();
    }

    final ciphertext = await getPhotoBytes(photoId: photo.id);

    if (photo.encryptedSize != null &&
        ciphertext.length != photo.encryptedSize) {
      throw const PhotoVerificationException();
    }

    try {
      return await encryptionService.decrypt(
        encryptedPhoto: EncryptedPhoto(
          metadata: PhotoEncryptionMetadata(
            keyId: photo.keyId!,
            encryptionVersion: photo.encryptionVersion!,
          ),
          nonce: base64Decode(photo.nonce!),
          ciphertext: ciphertext,
          mac: base64Decode(photo.mac!),
          checksum: photo.checksum!,
        ),
        coupleKey: coupleKey,
        photoId: photo.id.toString(),
      );
    } on SecretBoxAuthenticationError {
      throw const PhotoVerificationException();
    } on StateError {
      // Checksum mismatch.
      throw const PhotoVerificationException();
    } on FormatException {
      throw const PhotoVerificationException();
    }
  }

  Future<MemoryPhotoModel> uploadEncryptedBinary({
    required int photoId,
    required List<int> ciphertext,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
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
    final response = await _apiClient.patch(
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
