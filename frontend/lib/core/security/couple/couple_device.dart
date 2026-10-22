/// An active device of either couple member, as seen by key sharing.
class CoupleDevice {
  const CoupleDevice({
    required this.id,
    required this.isMine,
    required this.deviceName,
    required this.platform,
    required this.publicKey,
  });

  final int id;
  final bool isMine;
  final String? deviceName;
  final String platform;
  final String publicKey;

  factory CoupleDevice.fromJson(Map<String, dynamic> json) {
    return CoupleDevice(
      id: json['id'] as int,
      isMine: json['owner'] == 'me',
      deviceName: json['device_name'] as String?,
      platform: json['platform'] as String,
      publicKey: json['public_key'] as String,
    );
  }
}
