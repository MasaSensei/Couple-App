import 'package:cryptography/cryptography.dart';

class CoupleKey {
  const CoupleKey({required this.keyId, required this.secretKey});

  final String keyId;
  final SecretKey secretKey;
}
