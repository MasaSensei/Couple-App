import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Short code derived from a device public key. Users compare it on both
/// screens before approving a device, so the server cannot slip in its own key.
Future<String> deviceFingerprint(String publicKeyBase64) async {
  final digest = await Sha256().hash(base64Decode(publicKeyBase64));

  final hex = digest.bytes
      .take(10)
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();

  return [for (var i = 0; i < hex.length; i += 4) hex.substring(i, i + 4)]
      .join(' ');
}
