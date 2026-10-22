import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:frontend/core/security/couple/couple_key.dart';
import 'package:frontend/core/security/couple/couple_key_recovery_service.dart';

import 'dart:convert';

void main() {
  late CoupleKeyRecoveryService recoveryService;
  late CoupleKey originalKey;
  late List<int> recoveryKey;
  late Map<String, dynamic> payload;

  setUp(() async {
    recoveryService = CoupleKeyRecoveryService();

    originalKey = CoupleKey(
      keyId: 'test-couple-key-id',
      secretKey: SecretKey(List<int>.generate(32, (i) => i)),
    );

    recoveryKey = await recoveryService.generateRecoveryKey();

    payload = await recoveryService.createRecoveryPayload(
      coupleKey: originalKey,
      recoveryKey: recoveryKey,
    );
  });

  test('generates a 32-byte Recovery Key', () async {
    final key = await recoveryService.generateRecoveryKey();

    expect(key, hasLength(32));
    expect(key.every((byte) => byte >= 0 && byte <= 255), isTrue);
  });

  test('restores the original Couple Key', () async {
    final restored = await recoveryService.restoreFromRecoveryPayload(
      payload: payload,
      recoveryKey: recoveryKey,
    );

    expect(restored.keyId, originalKey.keyId);
    expect(
      await restored.secretKey.extractBytes(),
      await originalKey.secretKey.extractBytes(),
    );
  });

  test('rejects an incorrect Recovery Key', () async {
    final wrongKey = List<int>.filled(32, 99);

    await expectLater(
      recoveryService.restoreFromRecoveryPayload(
        payload: payload,
        recoveryKey: wrongKey,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a modified ciphertext', () async {
    final tamperedPayload = Map<String, dynamic>.from(payload);
    final ciphertext = base64Decode(payload['ciphertext'] as String);
    ciphertext[0] ^= 1;
    tamperedPayload['ciphertext'] = base64Encode(ciphertext);

    await expectLater(
      recoveryService.restoreFromRecoveryPayload(
        payload: tamperedPayload,
        recoveryKey: recoveryKey,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects an invalid Recovery Key length', () async {
    await expectLater(
      recoveryService.createRecoveryPayload(
        coupleKey: originalKey,
        recoveryKey: List<int>.filled(16, 1),
      ),
      throwsArgumentError,
    );
  });

  test('rejects an unsupported recovery format version', () async {
    final invalidPayload = Map<String, dynamic>.from(payload);
    invalidPayload['format_version'] = 999;

    await expectLater(
      recoveryService.restoreFromRecoveryPayload(
        payload: invalidPayload,
        recoveryKey: recoveryKey,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
