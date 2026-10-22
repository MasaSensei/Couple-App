import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'couple_key.dart';

class CoupleKeyRecoveryService {
  CoupleKeyRecoveryService({AesGcm? aesGcm})
    : _aesGcm = aesGcm ?? AesGcm.with256bits();

  static const int recoveryFormatVersion = 1;
  static const int recoveryKeyLength = 32;

  final AesGcm _aesGcm;

  /// Generates a random 256-bit Recovery Key.
  Future<List<int>> generateRecoveryKey() async {
    final keyData = SecretKeyData.random(length: recoveryKeyLength);
    return keyData.extractBytes();
  }

  /// Encrypts the existing Couple Key into a portable recovery payload.
  /// The Recovery Key must remain on the user's device or in their custody.
  Future<Map<String, dynamic>> createRecoveryPayload({
    required CoupleKey coupleKey,
    required List<int> recoveryKey,
  }) async {
    _validateRecoveryKey(recoveryKey);

    final coupleKeyBytes = await coupleKey.secretKey.extractBytes();
    final nonce = _aesGcm.newNonce();

    final secretBox = await _aesGcm.encrypt(
      coupleKeyBytes,
      secretKey: SecretKey(recoveryKey),
      nonce: nonce,
      aad: _buildAssociatedData(
        keyId: coupleKey.keyId,
        formatVersion: recoveryFormatVersion,
      ),
    );

    return {
      'format_version': recoveryFormatVersion,
      'key_id': coupleKey.keyId,
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  /// Restores the original Couple Key using the Recovery Key.
  /// Incorrect keys or modified payloads fail AES-GCM authentication.
  Future<CoupleKey> restoreFromRecoveryPayload({
    required Map<String, dynamic> payload,
    required List<int> recoveryKey,
  }) async {
    _validateRecoveryKey(recoveryKey);

    final formatVersion = payload['format_version'];
    final keyId = payload['key_id'];

    if (formatVersion != recoveryFormatVersion ||
        keyId is! String ||
        keyId.isEmpty) {
      throw const FormatException('Invalid recovery payload metadata.');
    }

    try {
      final nonce = base64Decode(payload['nonce'] as String);
      final ciphertext = base64Decode(payload['ciphertext'] as String);
      final mac = base64Decode(payload['mac'] as String);

      final secretBox = SecretBox(ciphertext, nonce: nonce, mac: Mac(mac));

      final coupleKeyBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: SecretKey(recoveryKey),
        aad: _buildAssociatedData(
          keyId: keyId,
          formatVersion: formatVersion as int,
        ),
      );

      if (coupleKeyBytes.length != 32) {
        throw const FormatException('Invalid recovered Couple Key length.');
      }

      return CoupleKey(keyId: keyId, secretKey: SecretKey(coupleKeyBytes));
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Recovery failed: incorrect Recovery Key or modified payload.',
      );
    }
  }

  void _validateRecoveryKey(List<int> recoveryKey) {
    if (recoveryKey.length != recoveryKeyLength ||
        recoveryKey.any((byte) => byte < 0 || byte > 255)) {
      throw ArgumentError('Recovery Key must contain exactly 32 bytes.');
    }
  }

  List<int> _buildAssociatedData({
    required String keyId,
    required int formatVersion,
  }) {
    return utf8.encode('couple-key-recovery-v$formatVersion:$keyId');
  }
}
