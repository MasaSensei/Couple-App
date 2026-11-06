import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/security/couple/couple_key.dart';
import 'package:frontend/core/security/couple/couple_key_manager.dart';
import 'package:frontend/core/security/couple/couple_key_provisioning_service.dart';
import 'package:frontend/core/security/couple/couple_key_package_repository.dart';
import 'package:frontend/core/security/device_identity_service.dart';
import 'package:frontend/core/security/device_repository.dart';
import 'package:frontend/core/security/encryption_errors.dart';
import 'package:frontend/core/security/photo/photo_encryption_metadata.dart';
import 'package:frontend/core/security/photo/photo_encryption_service.dart';
import 'package:frontend/features/memories/data/models/memory_photo_model.dart';
import 'package:frontend/features/memories/data/repositories/memory_photo_repository.dart';
import 'package:frontend/features/memories/providers/memory_photo_provider.dart';
import 'package:frontend/features/photo_booth/domain/photo_booth_document.dart';
import 'package:frontend/features/photo_booth/domain/photo_booth_templates.dart';
import 'package:frontend/features/photo_booth/providers/photo_booth_controller.dart';

import 'photo_booth_render_test.dart' show photo;

/// Records everything that would reach the server.
class RecordingPhotoRepository extends MemoryPhotoRepository {
  RecordingPhotoRepository() : super(ApiClient());

  final uploads = <List<int>>[];
  final metadata = <Map<String, Object?>>[];
  Map<String, Object?>? session;
  bool failUpload = false;

  MemoryPhotoModel _photo(int id, String status) => MemoryPhotoModel.fromJson({
    'id': id,
    'memory_id': 7,
    'mime_type': 'image/jpeg',
    'file_size': 1,
    'status': status,
    'sort_order': 0,
  });

  @override
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
    session = {
      'memoryId': memoryId,
      'mimeType': mimeType,
      'width': width,
      'height': height,
    };
    return _photo(42, 'pending');
  }

  @override
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
    metadata.add({
      'photoId': photoId,
      'keyId': keyId,
      'nonce': nonce,
      'mac': mac,
      'checksum': checksum,
    });
    return _photo(photoId, 'pending');
  }

  @override
  Future<MemoryPhotoModel> uploadEncryptedBinary({
    required int photoId,
    required List<int> ciphertext,
    required String filename,
  }) async {
    if (failUpload) throw const SocketException('offline');
    uploads.add(ciphertext);
    return _photo(photoId, 'uploaded');
  }

  @override
  Future<MemoryPhotoModel> completeUpload({required int photoId}) async =>
      _photo(photoId, 'verified');

  @override
  Future<List<MemoryPhotoModel>> getPhotos({required int memoryId}) async => [
    _photo(42, 'verified'),
  ];
}

class FixedKeyProvisioning extends CoupleKeyProvisioningService {
  FixedKeyProvisioning(this.key)
    : super(
        keyManager: CoupleKeyManager(),
        packageRepository: CoupleKeyPackageRepository(apiClient: ApiClient()),
        deviceRepository: DeviceRepository(apiClient: ApiClient()),
      );

  final CoupleKey key;

  @override
  Future<CoupleKey> provisionCurrentDevice({
    required String deviceIdentifier,
  }) async => key;
}

class FixedDeviceIdentity extends DeviceIdentityService {
  @override
  Future<String> getOrCreateDeviceId() async => 'device-1';
}

class RecordingSharer implements PhotoBoothSharer {
  final shared = <Uint8List>[];
  bool fail = false;

  @override
  Future<void> share(Uint8List png) async {
    if (fail) throw StateError('no share sheet');
    shared.add(png);
  }
}

bool isPng(List<int> b) =>
    b.length > 4 &&
    b[0] == 0x89 &&
    b[1] == 0x50 &&
    b[2] == 0x4E &&
    b[3] == 0x47;
bool isJpeg(List<int> b) =>
    b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;

void main() {
  final key = CoupleKey(
    keyId: 'couple-key',
    secretKey: SecretKey(List<int>.generate(32, (i) => i)),
  );
  late RecordingPhotoRepository repository;
  late RecordingSharer sharer;
  late ProviderContainer container;

  setUp(() {
    repository = RecordingPhotoRepository();
    sharer = RecordingSharer();
    container = ProviderContainer(
      overrides: [
        memoryPhotoRepositoryProvider.overrideWithValue(repository),
        coupleKeyProvisioningServiceProvider.overrideWithValue(
          FixedKeyProvisioning(key),
        ),
        deviceIdentityServiceProvider.overrideWithValue(FixedDeviceIdentity()),
        photoBoothSharerProvider.overrideWithValue(sharer),
      ],
    );
    // Keep the autoDispose controller alive for the whole test.
    container.listen(photoBoothControllerProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  PhotoBoothController controller() =>
      container.read(photoBoothControllerProvider.notifier);
  PhotoBoothDocument document() =>
      container.read(photoBoothControllerProvider).document;

  group('editing', () {
    test('photos are capped, removable and reorderable', () {
      final c = controller();
      c.addPhotos([
        for (var i = 0; i < 12; i++) Uint8List.fromList([i]),
      ], PhotoSourceKind.gallery);
      expect(document().photos, hasLength(PhotoBoothController.maxPhotos));

      final ids = document().photos.map((p) => p.id).toList();
      c.reorder(0, 2);
      expect(document().photos.map((p) => p.id).take(3), [
        ids[1],
        ids[2],
        ids[0],
      ]);

      c.removePhoto(ids[1]);
      expect(document().photos.map((p) => p.id), isNot(contains(ids[1])));
      expect(document().photos, hasLength(PhotoBoothController.maxPhotos - 1));
    });

    test('caption is limited and template switches keep the photos', () {
      final c = controller();
      c.setCaption('x' * 100);
      expect(document().caption.length, PhotoBoothDocument.maxCaptionLength);

      c.addPhotos([
        Uint8List.fromList([1]),
      ], PhotoSourceKind.memory);
      c.setTemplate(PhotoBoothTemplates.polaroid);
      expect(document().template.key, 'polaroid');
      expect(document().photos.single.source, PhotoSourceKind.memory);
    });

    test(
      'saving or sharing with no photos is refused without touching the server',
      () async {
        await expectLater(
          controller().saveToMemory(memoryId: 7, accent: Colors.pink),
          throwsA(isA<PhotoBoothException>()),
        );
        await expectLater(
          controller().share(accent: Colors.pink),
          throwsA(isA<PhotoBoothException>()),
        );

        expect(repository.session, isNull);
        expect(sharer.shared, isEmpty);
      },
    );
  });

  group('save to memory', () {
    testWidgets('uploads only ciphertext that decrypts with the couple key', (
      tester,
    ) async {
      await tester.runAsync(() async {
        controller()
          ..setTemplate(PhotoBoothTemplates.classic2)
          ..addPhotos([
            photo(300, 400),
            photo(400, 300),
          ], PhotoSourceKind.gallery)
          ..setCaption('Our day');

        await controller().saveToMemory(memoryId: 7, accent: Colors.pink);

        expect(repository.session!['memoryId'], 7);
        expect(repository.uploads, hasLength(1));
        final uploaded = repository.uploads.single;

        // What the server receives is not an image and does not contain the caption.
        expect(isPng(uploaded) || isJpeg(uploaded), isFalse);
        expect(
          latin1.decode(uploaded, allowInvalid: true),
          isNot(contains('Our day')),
        );

        // ...but it is the finished print, recoverable with the couple key only.
        final meta = repository.metadata.single;
        final decrypted = await PhotoEncryptionService().decrypt(
          encryptedPhoto: EncryptedPhoto(
            metadata: PhotoEncryptionMetadata(
              keyId: meta['keyId']! as String,
              encryptionVersion: PhotoEncryptionService.encryptionVersion,
            ),
            ciphertext: uploaded,
            nonce: base64Decode(meta['nonce']! as String),
            mac: base64Decode(meta['mac']! as String),
            checksum: meta['checksum']! as String,
          ),
          coupleKey: key,
          photoId: '42',
        );
        expect(
          isJpeg(decrypted),
          isTrue,
          reason: 'prepared (EXIF-free JPEG) like every memory photo',
        );
        expect(meta['keyId'], 'couple-key');

        expect(
          container.read(photoBoothControllerProvider).busy,
          PhotoBoothBusy.none,
        );
      });
    });

    testWidgets('a failed upload is reported and leaves the editor usable', (
      tester,
    ) async {
      await tester.runAsync(() async {
        repository.failUpload = true;
        controller().addPhotos([photo(200, 200)], PhotoSourceKind.gallery);

        await expectLater(
          controller().saveToMemory(memoryId: 7, accent: Colors.pink),
          throwsA(
            isA<PhotoBoothException>().having(
              (e) => e.message,
              'message',
              EncryptionMessages.uploadFailed,
            ),
          ),
        );

        final state = container.read(photoBoothControllerProvider);
        expect(state.busy, PhotoBoothBusy.none);
        expect(
          state.document.photos,
          hasLength(1),
          reason: 'nothing is lost, the user can retry',
        );
      });
    });
  });

  group('share', () {
    testWidgets(
      'hands a PNG to the system share sheet and nothing to the server',
      (tester) async {
        await tester.runAsync(() async {
          controller().addPhotos([photo(200, 300)], PhotoSourceKind.gallery);
          await controller().share(accent: Colors.pink);

          expect(isPng(sharer.shared.single), isTrue);
          expect(repository.session, isNull);
          expect(repository.uploads, isEmpty);
        });
      },
    );

    testWidgets('a share sheet failure is a friendly error', (tester) async {
      await tester.runAsync(() async {
        sharer.fail = true;
        controller().addPhotos([photo(200, 300)], PhotoSourceKind.gallery);

        await expectLater(
          controller().share(accent: Colors.pink),
          throwsA(isA<PhotoBoothException>()),
        );
        expect(
          container.read(photoBoothControllerProvider).busy,
          PhotoBoothBusy.none,
        );
      });
    });
  });

  test('photo booth and appearance code never logs or prints photo data', () {
    final offenders = <String>[];
    for (final dir in ['lib/features/photo_booth', 'lib/features/appearance']) {
      for (final file
          in Directory(dir)
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        if (RegExp(r'\b(print|debugPrint|log)\(').hasMatch(source)) {
          offenders.add(file.path);
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test(
    'photo booth code builds no URLs and talks to no endpoint of its own',
    () {
      for (final file in Directory(
        'lib/features/photo_booth',
      ).listSync(recursive: true).whereType<File>()) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains('http')), reason: file.path);
        expect(source, isNot(contains('apiClient')), reason: file.path);
      }
    },
  );
}
