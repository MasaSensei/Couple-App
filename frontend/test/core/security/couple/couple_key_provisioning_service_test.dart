import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/error/api_exception.dart';
import 'package:frontend/core/security/couple/couple_device.dart';
import 'package:frontend/core/security/couple/couple_key_manager.dart';
import 'package:frontend/core/security/couple/couple_key_package.dart';
import 'package:frontend/core/security/couple/couple_key_package_repository.dart';
import 'package:frontend/core/security/couple/couple_key_package_service.dart';
import 'package:frontend/core/security/couple/couple_key_provisioning_service.dart';
import 'package:frontend/core/security/couple/couple_key_storage.dart';
import 'package:frontend/core/security/device_key_service.dart';
import 'package:frontend/core/security/device_key_storage.dart';
import 'package:frontend/core/security/device_repository.dart';
import 'package:frontend/core/security/encryption_errors.dart';
import 'package:frontend/core/security/photo/photo_encryption_service.dart';

class FakeSecureStorage implements SecureStorage {
  final Map<String, String> values = {};

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => values[key];
}

/// In-memory stand-in for the Laravel API. It only ever sees what the
/// clients send: public keys and encrypted packages.
class FakeServer {
  final devices = <({int id, String user, String identifier, String publicKey})>[];
  final packages = <CoupleKeyPackage>[];
  final recoveryPackages = <String, Map<String, dynamic>>{};

  bool conflictOnCreate = false;

  void createPackage(Map<String, dynamic> data) {
    final keyIds = packages.map((p) => p.keyId).toSet();

    if (conflictOnCreate || keyIds.isNotEmpty && !keyIds.contains(data['key_id'])) {
      throw const ApiException(message: 'conflict', statusCode: 409);
    }

    packages.add(
      CoupleKeyPackage.fromJson({
        ...data,
        'id': packages.length + 1,
        'created_at': null,
        'updated_at': null,
        'revoked_at': null,
      }),
    );
  }
}

class FakePackageRepository extends CoupleKeyPackageRepository {
  FakePackageRepository(this.server, this.user);

  final FakeServer server;
  final String user;

  @override
  Future<List<CoupleKeyPackage>> getKeyPackages() async => server.packages;

  @override
  Future<void> createKeyPackage({
    required int deviceId,
    required String keyId,
    required int encryptionVersion,
    required String ephemeralPublicKey,
    required String nonce,
    required String ciphertext,
    required String mac,
  }) async {
    server.createPackage({
      'device_id': deviceId,
      'key_id': keyId,
      'encryption_version': encryptionVersion,
      'ephemeral_public_key': ephemeralPublicKey,
      'nonce': nonce,
      'ciphertext': ciphertext,
      'mac': mac,
    });
  }

  @override
  Future<List<CoupleDevice>> getCoupleDevices() async {
    return [
      for (final d in server.devices)
        CoupleDevice(
          id: d.id,
          isMine: d.user == user,
          deviceName: d.identifier,
          platform: 'android',
          publicKey: d.publicKey,
        ),
    ];
  }

  @override
  Future<Map<String, dynamic>?> getRecoveryPackage() async =>
      server.recoveryPackages[user];

  @override
  Future<void> putRecoveryPackage(Map<String, dynamic> payload) async {
    server.recoveryPackages[user] = payload;
  }
}

class FakeDeviceRepository extends DeviceRepository {
  FakeDeviceRepository(this.server, this.user);

  final FakeServer server;
  final String user;

  @override
  Future<List<Map<String, dynamic>>> getDevices() async {
    return [
      for (final d in server.devices.where((d) => d.user == user))
        {
          'id': d.id,
          'device_identifier': d.identifier,
          'public_key': d.publicKey,
          'revoked_at': null,
        },
    ];
  }
}

/// One phone: its own secure storage, device key and services.
class SimulatedDevice {
  SimulatedDevice._(this.identifier, this.storage, this.service);

  final String identifier;
  final FakeSecureStorage storage;
  final CoupleKeyProvisioningService service;

  static Future<SimulatedDevice> register(
    FakeServer server,
    String user,
    String identifier,
  ) async {
    final storage = FakeSecureStorage();
    final deviceKeyService = DeviceKeyService(
      storage: DeviceKeyStorage(storage: storage),
    );
    final publicKey = await deviceKeyService.initialize();

    server.devices.add((
      id: server.devices.length + 1,
      user: user,
      identifier: identifier,
      publicKey: publicKey,
    ));

    final packageRepository = FakePackageRepository(server, user);

    final keyManager = CoupleKeyManager(
      storage: CoupleKeyStorage(storage: storage),
      packageService: CoupleKeyPackageService(
        repository: packageRepository,
        deviceKeyService: deviceKeyService,
      ),
    );

    return SimulatedDevice._(
      identifier,
      storage,
      CoupleKeyProvisioningService(
        keyManager: keyManager,
        packageRepository: packageRepository,
        deviceRepository: FakeDeviceRepository(server, user),
      ),
    );
  }

  Future<List<int>> coupleKeyBytes() async {
    final key = await service.provisionCurrentDevice(
      deviceIdentifier: identifier,
    );
    return key.secretKey.extractBytes();
  }
}

void main() {
  late FakeServer server;

  setUp(() => server = FakeServer());

  test('first device of the couple creates the Couple Key', () async {
    final phoneA = await SimulatedDevice.register(server, 'A', 'phone-a');

    final key = await phoneA.coupleKeyBytes();

    expect(key, hasLength(32));
    expect(server.packages, hasLength(1));
    // Same key on the next call, nothing new uploaded.
    expect(await phoneA.coupleKeyBytes(), key);
    expect(server.packages, hasLength(1));
  });

  test('partner device cannot create a second Couple Key', () async {
    final phoneA = await SimulatedDevice.register(server, 'A', 'phone-a');
    await phoneA.coupleKeyBytes();

    final phoneB = await SimulatedDevice.register(server, 'B', 'phone-b');

    await expectLater(
      phoneB.coupleKeyBytes(),
      throwsA(isA<CoupleKeyUnavailableException>()),
    );
    expect(server.packages, hasLength(1));
    expect(phoneB.storage.values['couple_secret_key'], isNull);
  });

  test('losing the race to create the key leaves no stray local key', () async {
    final phoneA = await SimulatedDevice.register(server, 'A', 'phone-a');

    // The partner established a key between our read and our upload.
    server.conflictOnCreate = true;

    await expectLater(
      phoneA.coupleKeyBytes(),
      throwsA(isA<CoupleKeyUnavailableException>()),
    );
    expect(phoneA.storage.values['couple_secret_key'], isNull);
  });

  test('partner gets access after approval and can decrypt photos', () async {
    final phoneA = await SimulatedDevice.register(server, 'A', 'phone-a');
    final keyA = await phoneA.service.provisionCurrentDevice(
      deviceIdentifier: 'phone-a',
    );

    final phoneB = await SimulatedDevice.register(server, 'B', 'phone-b');

    final pending = await phoneA.service.pendingDevices();
    expect(pending.map((d) => d.deviceName), ['phone-b']);
    expect(pending.single.isMine, isFalse);

    await phoneA.service.authorizeDevice(pending.single);
    expect(await phoneA.service.pendingDevices(), isEmpty);

    final keyB = await phoneB.service.provisionCurrentDevice(
      deviceIdentifier: 'phone-b',
    );

    final photoService = PhotoEncryptionService();
    final encrypted = await photoService.encrypt(
      plaintext: [1, 2, 3, 4],
      coupleKey: keyA,
      photoId: '7',
    );

    expect(
      await photoService.decrypt(
        encryptedPhoto: encrypted,
        coupleKey: keyB,
        photoId: '7',
      ),
      [1, 2, 3, 4],
    );
  });

  test('a device does not accept a different key from the server', () async {
    final phoneA = await SimulatedDevice.register(server, 'A', 'phone-a');
    await phoneA.coupleKeyBytes();

    // A malicious server replaces the package with one for an attacker key.
    final original = server.packages.single;
    server.packages
      ..clear()
      ..add(
        CoupleKeyPackage.fromJson({
          'id': 2,
          'device_id': original.deviceId,
          'key_id': 'attacker-key',
          'encryption_version': 1,
          'ephemeral_public_key': original.ephemeralPublicKey,
          'nonce': original.nonce,
          'ciphertext': original.ciphertext,
          'mac': original.mac,
          'created_at': null,
          'updated_at': null,
          'revoked_at': null,
        }),
      );

    await expectLater(
      phoneA.coupleKeyBytes(),
      throwsA(isA<CoupleKeyUnavailableException>()),
    );
  });

  group('recovery', () {
    late SimulatedDevice phoneA;
    late List<int> originalKey;
    late String recoveryKey;

    setUp(() async {
      phoneA = await SimulatedDevice.register(server, 'A', 'phone-a');
      originalKey = await phoneA.coupleKeyBytes();
      recoveryKey = await phoneA.service.generateRecoveryKey();
      await phoneA.service.saveRecoveryKey(recoveryKey);
    });

    test('server stores only an encrypted recovery package', () async {
      final stored = server.recoveryPackages['A']!;

      expect(stored.keys, containsAll(['key_id', 'nonce', 'ciphertext', 'mac']));
      expect(stored.values.join(), isNot(contains(recoveryKey)));
    });

    test('scenario A: device lost, Recovery Key available -> access restored', () async {
      final newPhone = await SimulatedDevice.register(server, 'A', 'phone-a2');

      await expectLater(
        newPhone.coupleKeyBytes(),
        throwsA(isA<CoupleKeyUnavailableException>()),
      );

      final restored = await newPhone.service.restoreWithRecoveryKey(
        deviceIdentifier: 'phone-a2',
        recoveryKeyText: recoveryKey.toLowerCase(),
      );

      expect(await restored.secretKey.extractBytes(), originalKey);
      // The new device now has its own package, so it works without recovery next time.
      expect(server.packages.map((p) => p.deviceId), contains(2));
      expect(await newPhone.coupleKeyBytes(), originalKey);
    });

    test('scenario B: Recovery Key unavailable -> no access', () async {
      final newPhone = await SimulatedDevice.register(server, 'A', 'phone-a2');
      final wrongKey = await newPhone.service.generateRecoveryKey();

      await expectLater(
        newPhone.service.restoreWithRecoveryKey(
          deviceIdentifier: 'phone-a2',
          recoveryKeyText: wrongKey,
        ),
        throwsFormatException,
      );
      expect(newPhone.storage.values['couple_secret_key'], isNull);
      await expectLater(
        newPhone.coupleKeyBytes(),
        throwsA(isA<CoupleKeyUnavailableException>()),
      );
    });

    test('partner without a recovery package gets RecoveryUnavailable', () async {
      final phoneB = await SimulatedDevice.register(server, 'B', 'phone-b');

      await expectLater(
        phoneB.service.restoreWithRecoveryKey(
          deviceIdentifier: 'phone-b',
          recoveryKeyText: recoveryKey,
        ),
        throwsA(isA<RecoveryUnavailableException>()),
      );
    });

    test('scenario C: an active device approves a new device', () async {
      final tablet = await SimulatedDevice.register(server, 'A', 'tablet-a');

      final pending = await phoneA.service.pendingDevices();
      expect(pending.single.isMine, isTrue);

      await phoneA.service.authorizeDevice(pending.single);

      expect(await tablet.coupleKeyBytes(), originalKey);
    });
  });

  test('pending devices require a local Couple Key', () async {
    final phoneA = await SimulatedDevice.register(server, 'A', 'phone-a');

    await expectLater(
      phoneA.service.pendingDevices(),
      throwsA(isA<CoupleKeyUnavailableException>()),
    );
  });

  test('wrong Couple Key cannot decrypt a photo', () async {
    final photoService = PhotoEncryptionService();
    final keyManager = CoupleKeyManager(
      storage: CoupleKeyStorage(storage: FakeSecureStorage()),
    );
    final ourKey = await keyManager.generate();
    final otherCoupleKey = await keyManager.generate();

    final encrypted = await photoService.encrypt(
      plaintext: [9, 9, 9],
      coupleKey: ourKey,
      photoId: '1',
    );

    await expectLater(
      photoService.decrypt(
        encryptedPhoto: encrypted,
        coupleKey: otherCoupleKey,
        photoId: '1',
      ),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}
