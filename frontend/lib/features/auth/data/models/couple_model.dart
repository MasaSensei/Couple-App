import 'user_model.dart';

class CoupleModel {
  const CoupleModel({
    required this.id,
    required this.inviteCode,
    required this.members,
    required this.createdAt,
    this.relationshipStartedAt,
  });

  final int id;
  final String? inviteCode;
  final List<UserModel> members;
  final DateTime? createdAt;

  /// Anniversary the couple set themselves (date only); null when unset.
  final DateTime? relationshipStartedAt;

  factory CoupleModel.fromJson(Map<String, dynamic> json) {
    return CoupleModel(
      id: json['id'] as int,
      inviteCode: json['invite_code'] as String?,
      members: (json['members'] as List<dynamic>? ?? [])
          .map((member) => UserModel.fromJson(member as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      relationshipStartedAt: json['relationship_started_at'] == null
          ? null
          : DateTime.parse(json['relationship_started_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invite_code': inviteCode,
      'members': members.map((member) => member.toJson()).toList(),
      'created_at': createdAt?.toIso8601String(),
      'relationship_started_at': relationshipStartedAt == null
          ? null
          : _dateOnly(relationshipStartedAt!),
    };
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
