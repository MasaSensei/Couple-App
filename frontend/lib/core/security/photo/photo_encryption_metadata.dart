class PhotoEncryptionMetadata {
  const PhotoEncryptionMetadata({
    required this.keyId,
    required this.encryptionVersion,
  });

  final String keyId;
  final int encryptionVersion;

  Map<String, dynamic> toJson() {
    return {'key_id': keyId, 'encryption_version': encryptionVersion};
  }

  factory PhotoEncryptionMetadata.fromJson(Map<String, dynamic> json) {
    return PhotoEncryptionMetadata(
      keyId: json['key_id'] as String,
      encryptionVersion: json['encryption_version'] as int,
    );
  }
}
