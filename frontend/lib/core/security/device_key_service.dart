import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'device_key_storage.dart';

class DeviceKeyService {
  DeviceKeyService({DeviceKeyStorage? storage, X25519? algorithm})
    : _storage = storage ?? DeviceKeyStorage(),
      _algorithm = algorithm ?? X25519();

  final DeviceKeyStorage _storage;
  final X25519 _algorithm;

  Future<bool> hasDeviceKey() async {
    final privateKey = await _storage.readPrivateKey();

    return privateKey != null && privateKey.isNotEmpty;
  }

  Future<String> initialize() async {
    final existingPrivateKey = await _storage.readPrivateKey();

    if (existingPrivateKey != null && existingPrivateKey.isNotEmpty) {
      return _publicKeyFromPrivateKey(existingPrivateKey);
    }

    final keyPair = await _algorithm.newKeyPair();

    try {
      final privateKey = await keyPair.extract();
      final publicKey = await keyPair.extractPublicKey();

      await _storage.savePrivateKey(base64UrlEncode(privateKey.bytes));

      return base64Encode(publicKey.bytes);
    } finally {
      keyPair.destroy();
    }
  }

  Future<String> _publicKeyFromPrivateKey(String encodedPrivateKey) async {
    final privateKeyBytes = base64Url.decode(encodedPrivateKey);

    final keyPair = await _algorithm.newKeyPairFromSeed(privateKeyBytes);

    try {
      final publicKey = await keyPair.extractPublicKey();

      return base64Encode(publicKey.bytes);
    } finally {
      keyPair.destroy();
    }
  }

  Future<SimpleKeyPair> loadKeyPair() async {
    final encodedPrivateKey = await _storage.readPrivateKey();

    if (encodedPrivateKey == null || encodedPrivateKey.isEmpty) {
      throw StateError('Device private key has not been initialized.');
    }

    final privateKeyBytes = base64Url.decode(encodedPrivateKey);

    return _algorithm.newKeyPairFromSeed(privateKeyBytes);
  }
}
