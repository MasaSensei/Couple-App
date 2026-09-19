class DateModel {
  const DateModel({
    required this.id,
    required this.coupleId,
    required this.createdBy,
    required this.title,
    required this.description,
    required this.location,
    required this.scheduledAt,
    required this.status,
    required this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int coupleId;
  final int createdBy;

  final String title;
  final String? description;
  final String? location;

  final DateTime scheduledAt;

  final String status;
  final DateTime? completedAt;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DateModel.fromJson(Map<String, dynamic> json) {
    return DateModel(
      id: json['id'] as int,
      coupleId: json['couple_id'] as int,
      createdBy: json['created_by'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      status: json['status'] as String,
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );
  }
}
