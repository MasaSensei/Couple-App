/// How safely the couple's photos are stored, as reported by the server
/// (`GET /memories/protection`). The app never upgrades these numbers itself.
class MemoryProtectionSummary {
  const MemoryProtectionSummary({
    required this.photos,
    required this.protected,
    required this.backingUp,
    required this.restoring,
    required this.needsAttention,
    required this.uploading,
    required this.uploadFailed,
    required this.state,
    this.lastIntegrityCheckAt,
    this.lastVerifiedBackupAt,
  });

  final int photos;
  final int protected;
  final int backingUp;
  final int restoring;
  final int needsAttention;
  final int uploading;
  final int uploadFailed;

  /// protected, backing_up, restoring, needs_attention or empty.
  final String state;

  final DateTime? lastIntegrityCheckAt;
  final DateTime? lastVerifiedBackupAt;

  bool get isFullyProtected => state == 'protected';

  factory MemoryProtectionSummary.fromJson(Map<String, dynamic> json) {
    int count(String key) => (json[key] as num?)?.toInt() ?? 0;
    DateTime? date(String key) =>
        json[key] == null ? null : DateTime.tryParse(json[key].toString());

    return MemoryProtectionSummary(
      photos: count('photos'),
      protected: count('protected'),
      backingUp: count('backing_up'),
      restoring: count('restoring'),
      needsAttention: count('needs_attention'),
      uploading: count('uploading'),
      uploadFailed: count('upload_failed'),
      state: json['state'] as String? ?? 'empty',
      lastIntegrityCheckAt: date('last_integrity_check_at'),
      lastVerifiedBackupAt: date('last_verified_backup_at'),
    );
  }
}
