import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/security/couple/couple_key_manager.dart';
import 'package:frontend/core/security/device_identity_service.dart';
import 'package:frontend/core/security/device_repository.dart';
import 'package:frontend/core/security/photo/photo_encryption_service.dart';
import 'package:frontend/features/auth/providers/auth_dependencies.dart';
import 'package:frontend/features/device/providers/device_provider.dart';
import 'package:frontend/features/memories/data/models/memory_photo_model.dart';
import 'package:frontend/features/memories/data/repositories/memory_photo_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/core/security/couple/couple_key_provisioning_service.dart';
import 'package:frontend/core/security/couple/couple_key_package_repository.dart';

final memoryPhotoRepositoryProvider = Provider<MemoryPhotoRepository>((ref) {
  return MemoryPhotoRepository(ref.watch(apiClientProvider));
});

final coupleKeyManagerProvider = Provider<CoupleKeyManager>((ref) {
  return CoupleKeyManager();
});

final deviceIdentityServiceProvider = Provider<DeviceIdentityService>((ref) {
  return DeviceIdentityService();
});

final coupleKeyProvisioningServiceProvider =
    Provider<CoupleKeyProvisioningService>((ref) {
      final apiClient = ref.watch(apiClientProvider);

      return CoupleKeyProvisioningService(
        keyManager: ref.watch(coupleKeyManagerProvider),
        packageRepository: CoupleKeyPackageRepository(apiClient: apiClient),
        deviceRepository: DeviceRepository(apiClient: apiClient),
      );
    });

final photoEncryptionServiceProvider = Provider<PhotoEncryptionService>((ref) {
  return PhotoEncryptionService();
});

final memoryPhotoNotifierProvider =
    NotifierProvider<MemoryPhotoNotifier, AsyncValue<List<MemoryPhotoModel>>>(
      MemoryPhotoNotifier.new,
    );

class MemoryPhotoNotifier extends Notifier<AsyncValue<List<MemoryPhotoModel>>> {
  late MemoryPhotoRepository _repository;
  late CoupleKeyManager _coupleKeyManager;
  late DeviceIdentityService _deviceIdentityService;
  late PhotoEncryptionService _photoEncryptionService;
  late CoupleKeyProvisioningService _coupleKeyProvisioningService;

  final ImagePicker _picker = ImagePicker();

  @override
  AsyncValue<List<MemoryPhotoModel>> build() {
    _repository = ref.watch(memoryPhotoRepositoryProvider);
    _coupleKeyManager = ref.watch(coupleKeyManagerProvider);
    _deviceIdentityService = ref.watch(deviceIdentityServiceProvider);
    _photoEncryptionService = ref.watch(photoEncryptionServiceProvider);
    _coupleKeyProvisioningService = ref.watch(
      coupleKeyProvisioningServiceProvider,
    );

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

  Future<List<int>> getDecryptedPhotoBytes({
    required MemoryPhotoModel photo,
  }) async {
    if (photo.encryptionVersion == null) {
      throw StateError('This photo is not encrypted.');
    }

    final deviceIdentifier = await _deviceIdentityService.getOrCreateDeviceId();

    final devices = await ref.read(devicesProvider.future);

    final matchingDevices = devices.where(
      (device) =>
          device.deviceIdentifier == deviceIdentifier &&
          device.revokedAt == null,
    );

    if (matchingDevices.length != 1) {
      throw StateError('Current device is not registered uniquely.');
    }

    final coupleKey = await _coupleKeyManager.getOrRestore(
      deviceId: matchingDevices.single.id,
    );

    return _repository.getDecryptedPhotoBytes(
      photo: photo,
      coupleKey: coupleKey,
      encryptionService: _photoEncryptionService,
    );
  }

  Future<void> pickAndUpload({required int memoryId}) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    await uploadPhoto(memoryId: memoryId, file: File(pickedFile.path));
  }

  Future<void> uploadPhoto({required int memoryId, required File file}) async {
    state = const AsyncLoading();

    try {
      final originalBytes = await file.readAsBytes();
      final deviceIdentifier = await _deviceIdentityService
          .getOrCreateDeviceId();

      final devices = await ref.read(devicesProvider.future);

      final matchingDevices = devices.where(
        (device) =>
            device.deviceIdentifier == deviceIdentifier &&
            device.revokedAt == null,
      );

      if (matchingDevices.length != 1) {
        throw StateError(
          'Current device is not registered uniquely. Please register this device again.',
        );
      }

      final coupleKey = await _coupleKeyProvisioningService
          .provisionCurrentDevice(deviceIdentifier: deviceIdentifier);

      final photo = await _repository.createUploadSession(
        memoryId: memoryId,
        originalFilename: file.uri.pathSegments.last,
        mimeType: _mimeTypeFromPath(file.path),
        fileSize: originalBytes.length,
      );

      final encryptedPhoto = await _photoEncryptionService.encrypt(
        plaintext: originalBytes,
        coupleKey: coupleKey,
        photoId: photo.id.toString(),
      );

      final nonce = base64Encode(encryptedPhoto.nonce);
      final mac = base64Encode(encryptedPhoto.mac);
      final ciphertext = encryptedPhoto.ciphertext;
      final checksum = encryptedPhoto.checksum;

      await _repository.updateEncryptionMetadata(
        photoId: photo.id,
        encryptionVersion: PhotoEncryptionService.encryptionVersion,
        encryptionAlgorithm: 'AES-256-GCM',
        keyId: coupleKey.keyId,
        nonce: nonce,
        mac: mac,
        encryptedSize: ciphertext.length,
        checksum: checksum,
      );

      final uploadedPhoto = await _repository.uploadEncryptedBinary(
        photoId: photo.id,
        ciphertext: ciphertext,
        filename: '${photo.id}.enc',
      );

      await _repository.completeUpload(photoId: uploadedPhoto.id);

      await loadPhotos(memoryId: memoryId);
    } catch (error, stackTrace) {
      debugPrint('Photo upload error: $error');
      debugPrintStack(stackTrace: stackTrace);

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
    switch (path.split('.').last.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        throw UnsupportedError('Unsupported image format.');
    }
  }
}
