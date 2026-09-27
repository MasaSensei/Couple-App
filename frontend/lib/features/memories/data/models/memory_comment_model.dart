class MemoryCommentModel {
  const MemoryCommentModel({
    required this.id,
    required this.memoryId,
    required this.userId,
    required this.userName,
    required this.body,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int memoryId;

  final int userId;
  final String userName;

  final String body;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MemoryCommentModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    return MemoryCommentModel(
      id: json['id'] as int,
      memoryId: json['memory_id'] as int,
      userId: user?['id'] as int? ?? 0,
      userName: user?['name'] as String? ?? '',
      body: json['body'] as String,
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
