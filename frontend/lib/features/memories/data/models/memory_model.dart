class MemoryModel {
  const MemoryModel({
    required this.id,
    required this.coupleId,
    required this.createdBy,
    this.dateId,
    required this.title,
    this.description,
    required this.memoryDate,
    this.locationName,
    this.locationAddress,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int coupleId;
  final int createdBy;
  final int? dateId;

  final String title;
  final String? description;

  final DateTime memoryDate;

  final String? locationName;
  final String? locationAddress;

  final double? latitude;
  final double? longitude;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MemoryModel.fromJson(Map<String, dynamic> json) {
    return MemoryModel(
      id: json['id'] as int,
      coupleId: json['couple_id'] as int,
      createdBy: json['created_by'] as int,
      dateId: json['date_id'] as int?,
      title: json['title'] as String,
      description: json['description'] as String?,
      memoryDate: DateTime.parse(json['memory_date'] as String),
      locationName: json['location_name'] as String?,
      locationAddress: json['location_address'] as String?,
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}
