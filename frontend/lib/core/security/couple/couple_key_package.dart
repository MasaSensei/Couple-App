class CoupleKeyPackage {
  const CoupleKeyPackage({
    required this.id,
    required this.deviceId,
    required this.keyId,
    required this.encryptionVersion,
    required this.ephemeralPublicKey,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
    required this.createdAt,
    required this.updatedAt,
    required this.revokedAt,
  });

  final int id;
  final int deviceId;
  final String keyId;
  final int encryptionVersion;
  final String ephemeralPublicKey;
  final String nonce;
  final String ciphertext;
  final String mac;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? revokedAt;

  factory CoupleKeyPackage.fromJson(Map<String, dynamic> json) {
    return CoupleKeyPackage(
      id: json['id'] as int,
      deviceId: json['device_id'] as int,
      keyId: json['key_id'] as String,
      encryptionVersion: json['encryption_version'] as int,
      ephemeralPublicKey: json['ephemeral_public_key'] as String,
      nonce: json['nonce'] as String,
      ciphertext: json['ciphertext'] as String,
      mac: json['mac'] as String,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      revokedAt: _parseDateTime(json['revoked_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.parse(value as String);
  }
}
