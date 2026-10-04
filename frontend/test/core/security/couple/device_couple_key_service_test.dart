import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/security/couple/couple_key.dart';
import 'package:frontend/core/security/couple/couple_key_wrapper.dart';
import 'package:frontend/core/security/couple/device_couple_key_service.dart';

void main() {
  group('DeviceCoupleKeyService', () {
    test('wraps couple key for a specific device', () async {
      final service = DeviceCoupleKeyService();

      final recipientKeyPair = await X25519().newKeyPair();

      final recipientPublicKey = await recipientKeyPair.extractPublicKey();

      final coupleKey = CoupleKey(
        keyId: 'couple-key-1',
        secretKey: SecretKey(List<int>.generate(32, (index) => index)),
      );

      final result = await service.wrapForDevice(
        deviceId: 123,
        coupleKey: coupleKey,
        devicePublicKey: recipientPublicKey,
      );

      expect(result.deviceId, 123);

      expect(result.wrappedKey.keyId, 'couple-key-1');

      expect(result.wrappedKey.encryptionVersion, 1);

      expect(result.wrappedKey.ciphertext, isNotEmpty);
    });

    test('wrapped couple key can be recovered by the target device', () async {
      final wrapper = CoupleKeyWrapper();

      final service = DeviceCoupleKeyService(wrapper: wrapper);

      final recipientKeyPair = await X25519().newKeyPair();

      final recipientPublicKey = await recipientKeyPair.extractPublicKey();

      final originalBytes = List<int>.generate(32, (index) => index + 1);

      final coupleKey = CoupleKey(
        keyId: 'couple-key-2',
        secretKey: SecretKey(originalBytes),
      );

      final result = await service.wrapForDevice(
        deviceId: 456,
        coupleKey: coupleKey,
        devicePublicKey: recipientPublicKey,
      );

      final recoveredKey = await wrapper.unwrap(
        wrappedKey: result.wrappedKey,
        recipientKeyPair: recipientKeyPair,
      );

      final recoveredBytes = await recoveredKey.extractBytes();

      expect(recoveredBytes, originalBytes);
    });

    test('same couple key can be wrapped for two devices', () async {
      final wrapper = CoupleKeyWrapper();

      final service = DeviceCoupleKeyService(wrapper: wrapper);

      final deviceAKeyPair = await X25519().newKeyPair();

      final deviceBKeyPair = await X25519().newKeyPair();

      final deviceAPublicKey = await deviceAKeyPair.extractPublicKey();

      final deviceBPublicKey = await deviceBKeyPair.extractPublicKey();

      final originalBytes = List<int>.generate(32, (index) => index + 10);

      final coupleKey = CoupleKey(
        keyId: 'couple-key-multi-device',
        secretKey: SecretKey(originalBytes),
      );

      final wrappedForDeviceA = await service.wrapForDevice(
        deviceId: 100,
        coupleKey: coupleKey,
        devicePublicKey: deviceAPublicKey,
      );

      final wrappedForDeviceB = await service.wrapForDevice(
        deviceId: 200,
        coupleKey: coupleKey,
        devicePublicKey: deviceBPublicKey,
      );

      expect(wrappedForDeviceA.deviceId, 100);

      expect(wrappedForDeviceB.deviceId, 200);

      expect(
        wrappedForDeviceA.wrappedKey.keyId,
        wrappedForDeviceB.wrappedKey.keyId,
      );

      final recoveredByDeviceA = await wrapper.unwrap(
        wrappedKey: wrappedForDeviceA.wrappedKey,
        recipientKeyPair: deviceAKeyPair,
      );

      final recoveredByDeviceB = await wrapper.unwrap(
        wrappedKey: wrappedForDeviceB.wrappedKey,
        recipientKeyPair: deviceBKeyPair,
      );

      expect(await recoveredByDeviceA.extractBytes(), originalBytes);

      expect(await recoveredByDeviceB.extractBytes(), originalBytes);
    });
    test('device cannot unwrap another device wrapped key', () async {
      final wrapper = CoupleKeyWrapper();

      final service = DeviceCoupleKeyService(wrapper: wrapper);

      final deviceAKeyPair = await X25519().newKeyPair();

      final deviceBKeyPair = await X25519().newKeyPair();

      final deviceBPublicKey = await deviceBKeyPair.extractPublicKey();

      final coupleKey = CoupleKey(
        keyId: 'couple-key-isolation',
        secretKey: SecretKey(List<int>.filled(32, 42)),
      );

      final wrappedForDeviceB = await service.wrapForDevice(
        deviceId: 200,
        coupleKey: coupleKey,
        devicePublicKey: deviceBPublicKey,
      );

      expect(
        () => wrapper.unwrap(
          wrappedKey: wrappedForDeviceB.wrappedKey,
          recipientKeyPair: deviceAKeyPair,
        ),
        throwsA(anything),
      );
    });
  });
}
