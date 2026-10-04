import 'package:cryptography/cryptography.dart';

class CoupleKeyService {
  static const int keyLength = 32;

  Future<SecretKey> generateKey() async {
    final keyData = SecretKeyData.random(length: keyLength);

    return keyData;
  }
}
