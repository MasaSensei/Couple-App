class CoupleInvitationModel {
  const CoupleInvitationModel({
    required this.id,
    required this.coupleId,
    required this.token,
    required this.status,
    required this.expiresAt,
    required this.acceptedAt,
    required this.createdAt,
  });

  final int id;
  final int? coupleId;
  final String? token;
  final String status;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime? createdAt;

  factory CoupleInvitationModel.fromJson(Map<String, dynamic> json) {
    return CoupleInvitationModel(
      id: json['id'] as int,
      coupleId: json['couple_id'] as int?,
      token: json['token'] as String?,
      status: json['status'] as String,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      acceptedAt: json['accepted_at'] == null
          ? null
          : DateTime.parse(json['accepted_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );
  }
}
