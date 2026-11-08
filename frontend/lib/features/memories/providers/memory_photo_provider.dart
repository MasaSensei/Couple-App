import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/security/couple/couple_key.dart';
import 'package:frontend/core/security/couple/couple_key_manager.dart';
import 'package:frontend/core/security/device_identity_service.dart';
import 'package:frontend/core/security/device_repository.dart';
import 'package:frontend/core/security/encryption_errors.dart';
import 'package:frontend/core/security/photo/photo_encryption_service.dart';
import 'package:frontend/core/security/photo/photo_preparation_service.dart';
import 'package:frontend/features/auth/providers/auth_dependencies.dart';
import 'package:frontend/features/auth/providers/auth_providers.dart';
import 'package:frontend/features/auth/providers/auth_state.dart';
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

final photoPreparationServiceProvider = Provider<PhotoPreparationService>((
  ref,
) {
  return const PhotoPreparationService();
});

final memoryPhotoNotifierProvider =
    NotifierProvider<MemoryPhotoNotifier, AsyncValue<List<MemoryPhotoModel>>>(
      MemoryPhotoNotifier.new,
    );

/// Upload failed; [message] is safe to show the user. The picked file is untouched.
class PhotoUploadException implements Exception {
  const PhotoUploadException(this.message);

  final String message;
}

class MemoryPhotoNotifier extends Notifier<AsyncValue<List<MemoryPhotoModel>>> {
  late MemoryPhotoRepository _repository;
  late DeviceIdentityService _deviceIdentityService;
  late PhotoEncryptionService _photoEncryptionService;
  late PhotoPreparationService _photoPreparationService;
  late CoupleKeyProvisioningService _coupleKeyProvisioningService;

  final ImagePicker _picker = ImagePicker();

  Future<CoupleKey>? _coupleKey;

  /// Decrypted bytes of recently shown photos, in memory only (never written
  /// to disk). Avoids re-downloading and re-decrypting covers while a
  /// timeline scrolls. Bounded; cleared on logout and on key reset.
  final _decrypted = _DecryptedPhotoCache();

  @override
  AsyncValue<List<MemoryPhotoModel>> build() {
    ref.listen(authNotifierProvider.select((s) => s.status), (_, status) {
      if (status != AuthStatus.authenticated) resetKeyCache();
    });

    _repository = ref.watch(memoryPhotoRepositoryProvider);
    _deviceIdentityService = ref.watch(deviceIdentityServiceProvider);
    _photoEncryptionService = ref.watch(photoEncryptionServiceProvider);
    _photoPreparationService = ref.watch(photoPreparationServiceProvider);
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

  /// Couple Key for this device, fetched once per session.
  /// Throws [CoupleKeyUnavailableException] when the device was not given access.
  Future<CoupleKey> _currentCoupleKey() async {
    final future = _coupleKey ??= () async {
      final deviceIdentifier = await _deviceIdentityService
          .getOrCreateDeviceId();

      return _coupleKeyProvisioningService.provisionCurrentDevice(
        deviceIdentifier: deviceIdentifier,
      );
    }();

    try {
      return await future;
    } catch (_) {
      _coupleKey = null;
      rethrow;
    }
  }

  /// Forget the cached key, e.g. after the user restored access.
  void resetKeyCache() {
    _coupleKey = null;
    _decrypted.clear();
  }

  /// Decrypted, authenticated photo bytes. Throws
  /// [CoupleKeyUnavailableException] or [PhotoVerificationException].
  Future<List<int>> getDecryptedPhotoBytes({required MemoryPhotoModel photo}) {
    return _decrypted.getOrLoad(photo, () async {
      return _repository.getDecryptedPhotoBytes(
        photo: photo,
        coupleKey: await _currentCoupleKey(),
        encryptionService: _photoEncryptionService,
      );
    });
  }

  Future<File?> pickPhoto() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    return pickedFile == null ? null : File(pickedFile.path);
  }

  /// prepare -> encrypt -> upload ciphertext -> server verifies checksum.
  /// Throws [PhotoUploadException]; the original file is never modified or deleted.
  Future<void> uploadPhoto({required int memoryId, required File file}) async {
    final Uint8List bytes;

    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw const PhotoUploadException(EncryptionMessages.encryptionFailed);
    }

    await uploadPhotoBytes(memoryId: memoryId, bytes: bytes);
  }

  /// Same encrypted pipeline for images created on the device (Photo Booth):
  /// the plaintext [bytes] never leave this method unencrypted.
  Future<void> uploadPhotoBytes({
    required int memoryId,
    required Uint8List bytes,
  }) async {
    final previous = state;
    state = const AsyncLoading();

    try {
      await _upload(memoryId: memoryId, bytes: bytes);
    } on PhotoUploadException {
      state = previous;
      rethrow;
    }

    await loadPhotos(memoryId: memoryId);
  }

  Future<void> _upload({
    required int memoryId,
    required Uint8List bytes,
  }) async {
    final PreparedPhoto prepared;
    final CoupleKey coupleKey;

    try {
      prepared = await _photoPreparationService.prepare(bytes);
    } catch (_) {
      throw const PhotoUploadException(EncryptionMessages.encryptionFailed);
    }

    try {
      coupleKey = await _currentCoupleKey();
    } on CoupleKeyUnavailableException {
      throw const PhotoUploadException(EncryptionMessages.keyUnavailable);
    } catch (_) {
      throw const PhotoUploadException(EncryptionMessages.uploadFailed);
    }

    final MemoryPhotoModel photo;

    try {
      photo = await _repository.createUploadSession(
        memoryId: memoryId,
        mimeType: PreparedPhoto.mimeType,
        fileSize: prepared.bytes.length,
        width: prepared.width,
        height: prepared.height,
      );
    } catch (_) {
      throw const PhotoUploadException(EncryptionMessages.uploadFailed);
    }

    // The photo id is bound into the key derivation and AAD.
    final EncryptedPhoto encryptedPhoto;

    try {
      encryptedPhoto = await _photoEncryptionService.encrypt(
        plaintext: prepared.bytes,
        coupleKey: coupleKey,
        photoId: photo.id.toString(),
      );

      // Never upload ciphertext this device has not proven it can decrypt.
      await _photoEncryptionService.verifyRoundTrip(
        encryptedPhoto: encryptedPhoto,
        plaintext: prepared.bytes,
        coupleKey: coupleKey,
        photoId: photo.id.toString(),
      );
    } catch (_) {
      throw const PhotoUploadException(EncryptionMessages.encryptionFailed);
    }

    try {
      await _repository.updateEncryptionMetadata(
        photoId: photo.id,
        encryptionVersion: PhotoEncryptionService.encryptionVersion,
        encryptionAlgorithm: 'AES-256-GCM',
        keyId: coupleKey.keyId,
        nonce: base64Encode(encryptedPhoto.nonce),
        mac: base64Encode(encryptedPhoto.mac),
        encryptedSize: encryptedPhoto.ciphertext.length,
        checksum: encryptedPhoto.checksum,
      );

      await _repository.uploadEncryptedBinary(
        photoId: photo.id,
        ciphertext: encryptedPhoto.ciphertext,
        filename: '${photo.id}.enc',
      );

      final completed = await _repository.completeUpload(photoId: photo.id);

      if (completed.status != 'verified') {
        throw StateError('Upload was not verified.');
      }
    } catch (_) {
      throw const PhotoUploadException(EncryptionMessages.uploadFailed);
    }
  }

  /// Moves a photo to the trash. Returns false if the server refused.
  Future<bool> deletePhoto({
    required int memoryId,
    required int photoId,
  }) async {
    try {
      await _repository.deletePhoto(photoId: photoId);
      await loadPhotos(memoryId: memoryId);

      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);

      return false;
    }
  }

  Future<List<MemoryPhotoModel>> loadTrash({required int memoryId}) {
    return _repository.getTrash(memoryId: memoryId);
  }

  /// Brings a photo back from the trash. Returns false if it can no longer be restored.
  Future<bool> restorePhoto({
    required int memoryId,
    required int photoId,
  }) async {
    try {
      await _repository.restorePhoto(photoId: photoId);
      await loadPhotos(memoryId: memoryId);

      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Small LRU of decrypted photo bytes keyed by photo id + checksum (a
/// changed or replaced photo never hits a stale entry). Failed loads are not
/// cached, so a retry tries again.
class _DecryptedPhotoCache {
  static const _maxEntries = 32;
  static const _maxBytes = 48 * 1024 * 1024;

  final _entries = <String, Future<List<int>>>{};
  final _sizes = <String, int>{};

  Future<List<int>> getOrLoad(
    MemoryPhotoModel photo,
    Future<List<int>> Function() load,
  ) {
    final key = '${photo.id}:${photo.checksum}';
    final hit = _entries.remove(key);
    if (hit != null) {
      _entries[key] = hit; // most recently used last
      return hit;
    }

    final future = load();
    _entries[key] = future;
    future.then(
      (bytes) {
        if (!_entries.containsKey(key)) return;
        _sizes[key] = bytes.length;
        _evict();
      },
      onError: (_) {
        _entries.remove(key);
        _sizes.remove(key);
      },
    );
    _evict();
    return future;
  }

  void _evict() {
    var total = _sizes.values.fold<int>(0, (a, b) => a + b);
    while (_entries.length > _maxEntries || total > _maxBytes) {
      final oldest = _entries.keys.first;
      _entries.remove(oldest);
      total -= _sizes.remove(oldest) ?? 0;
    }
  }

  void clear() {
    _entries.clear();
    _sizes.clear();
  }
}
