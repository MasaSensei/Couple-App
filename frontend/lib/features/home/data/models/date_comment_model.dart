class DateCommentModel {
  const DateCommentModel({
    required this.id,
    required this.dateId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int dateId;
  final int userId;
  final String? userName;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DateCommentModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    return DateCommentModel(
      id: json['id'] as int,
      dateId: json['date_id'] as int,
      userId: json['user_id'] as int,
      userName: user?['name'] as String?,
      content: json['content'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );
  }
}
