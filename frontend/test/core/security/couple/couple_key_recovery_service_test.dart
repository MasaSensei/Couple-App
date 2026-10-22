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

  test('formats Recovery Key as grouped Base32 and parses it back', () {
    final formatted = recoveryService.formatRecoveryKey(recoveryKey);

    expect(formatted, matches(RegExp(r'^([A-Z2-7]{4}-){12}[A-Z2-7]{4}$')));
    expect(recoveryService.parseRecoveryKey(formatted), recoveryKey);
  });

  test('parses Recovery Key regardless of case, spaces and dashes', () {
    final formatted = recoveryService.formatRecoveryKey(recoveryKey);
    final typed = formatted.toLowerCase().replaceAll('-', ' ');

    expect(recoveryService.parseRecoveryKey(typed), recoveryKey);
  });

  test('formats a known Recovery Key deterministically', () {
    final zeros = List<int>.filled(32, 0);

    expect(
      recoveryService.formatRecoveryKey(zeros),
      List.filled(13, 'AAAA').join('-'),
    );
  });

  test('rejects Recovery Key text with invalid characters or length', () {
    final formatted = recoveryService.formatRecoveryKey(recoveryKey);

    expect(
      () => recoveryService.parseRecoveryKey(formatted.replaceFirst(
        RegExp(r'[A-Z2-7]'),
        '1',
      )),
      throwsFormatException,
    );
    expect(
      () => recoveryService.parseRecoveryKey(formatted.substring(0, 20)),
      throwsFormatException,
    );
    expect(
      () => recoveryService.parseRecoveryKey('${formatted}AB'),
      throwsFormatException,
    );
  });

  test('restores the Couple Key from typed Recovery Key text', () async {
    final typed = recoveryService.formatRecoveryKey(recoveryKey);

    final restored = await recoveryService.restoreFromRecoveryPayload(
      payload: payload,
      recoveryKey: recoveryService.parseRecoveryKey(typed),
    );

    expect(
      await restored.secretKey.extractBytes(),
      await originalKey.secretKey.extractBytes(),
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
