import 'couple_key_wrapper.dart';

class DeviceWrappedCoupleKey {
  const DeviceWrappedCoupleKey({
    required this.deviceId,
    required this.wrappedKey,
  });

  final int deviceId;
  final WrappedCoupleKey wrappedKey;

  Map<String, dynamic> toJson() {
    return {'device_id': deviceId, 'wrapped_key': wrappedKey.toJson()};
  }

  factory DeviceWrappedCoupleKey.fromJson(Map<String, dynamic> json) {
    return DeviceWrappedCoupleKey(
      deviceId: json['device_id'] as int,
      wrappedKey: WrappedCoupleKey.fromJson(
        json['wrapped_key'] as Map<String, dynamic>,
      ),
    );
  }
}
