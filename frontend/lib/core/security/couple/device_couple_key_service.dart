import 'package:cryptography/cryptography.dart';

import 'couple_key.dart';
import 'couple_key_wrapper.dart';
import 'device_wrapped_couple_key.dart';

class DeviceCoupleKeyService {
  DeviceCoupleKeyService({CoupleKeyWrapper? wrapper})
    : _wrapper = wrapper ?? CoupleKeyWrapper();

  final CoupleKeyWrapper _wrapper;

  Future<DeviceWrappedCoupleKey> wrapForDevice({
    required int deviceId,
    required CoupleKey coupleKey,
    required SimplePublicKey devicePublicKey,
  }) async {
    final wrappedKey = await _wrapper.wrap(
      keyId: coupleKey.keyId,
      coupleKey: coupleKey.secretKey,
      recipientPublicKey: devicePublicKey,
    );

    return DeviceWrappedCoupleKey(deviceId: deviceId, wrappedKey: wrappedKey);
  }
}
