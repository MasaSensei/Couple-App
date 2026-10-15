class MemoryPhotoModel {
  const MemoryPhotoModel({
    required this.id,
    required this.memoryId,
    required this.uploadedBy,
    this.originalFilename,
    required this.mimeType,
    required this.fileSize,
    this.width,
    this.height,
    this.encryptionVersion,
    this.encryptionAlgorithm,
    this.keyId,
    this.nonce,
    this.mac,
    this.encryptedSize,
    this.checksum,
    required this.status,
    required this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int memoryId;
  final int uploadedBy;

  final String? originalFilename;

  final String mimeType;
  final int fileSize;

  final int? width;
  final int? height;

  final int? encryptionVersion;
  final String? encryptionAlgorithm;
  final String? keyId;
  final String? nonce;
  final String? mac;
  final int? encryptedSize;
  final String? checksum;

  final String status;
  final int sortOrder;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MemoryPhotoModel.fromJson(Map<String, dynamic> json) {
    return MemoryPhotoModel(
      id: json['id'] as int,
      memoryId: json['memory_id'] as int,
      uploadedBy: json['uploaded_by'] as int,
      originalFilename: json['original_filename'] as String?,
      mimeType: json['mime_type'] as String,
      fileSize: json['file_size'] as int,
      width: _parseInt(json['width']),
      height: _parseInt(json['height']),
      encryptionVersion: _parseInt(json['encryption_version']),
      encryptedSize: _parseInt(json['encrypted_size']),
      encryptionAlgorithm: json['encryption_algorithm'] as String?,
      keyId: json['key_id'] as String?,
      nonce: json['nonce'] as String?,
      mac: json['mac'] as String?,
      checksum: json['checksum'] as String?,
      status: json['status'] as String,
      sortOrder: json['sort_order'] as int,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);

    return null;
  }
}
