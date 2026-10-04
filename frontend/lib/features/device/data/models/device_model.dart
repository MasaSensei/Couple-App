class DeviceModel {
  const DeviceModel({
    required this.id,
    required this.deviceIdentifier,
    required this.deviceName,
    required this.platform,
    required this.publicKey,
    required this.lastSeenAt,
    required this.revokedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String deviceIdentifier;
  final String? deviceName;
  final String platform;
  final String publicKey;
  final DateTime? lastSeenAt;
  final DateTime? revokedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as int,
      deviceIdentifier: json['device_identifier'] as String,
      deviceName: json['device_name'] as String?,
      platform: json['platform'] as String,
      publicKey: json['public_key'] as String,
      lastSeenAt: _parseDateTime(json['last_seen_at']),
      revokedAt: _parseDateTime(json['revoked_at']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.parse(value as String);
  }
}
