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
      width: json['width'] as int?,
      height: json['height'] as int?,
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
}
