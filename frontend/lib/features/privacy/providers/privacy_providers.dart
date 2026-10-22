import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/security/couple/couple_device.dart';
import 'package:frontend/core/security/device_fingerprint.dart';
import 'package:frontend/core/security/device_key_service.dart';
import 'package:frontend/core/security/encryption_errors.dart';
import 'package:frontend/features/memories/providers/memory_photo_provider.dart';

class EncryptionStatus {
  const EncryptionStatus({
    required this.hasAccess,
    required this.hasRecoveryKey,
    required this.pendingDevices,
  });

  /// This device holds the Couple Key.
  final bool hasAccess;
  final bool hasRecoveryKey;

  /// Devices (own or partner's) waiting for this device to approve them.
  final List<CoupleDevice> pendingDevices;
}

/// Initializes encryption for the couple on first use (the first device
/// creates the Couple Key) and reports what the user still needs to do.
final encryptionStatusProvider = FutureProvider.autoDispose<EncryptionStatus>((
  ref,
) async {
  final service = ref.watch(coupleKeyProvisioningServiceProvider);
  final deviceIdentifier = await ref
      .watch(deviceIdentityServiceProvider)
      .getOrCreateDeviceId();

  try {
    await service.provisionCurrentDevice(deviceIdentifier: deviceIdentifier);
  } on CoupleKeyUnavailableException {
    return const EncryptionStatus(
      hasAccess: false,
      hasRecoveryKey: false,
      pendingDevices: [],
    );
  }

  return EncryptionStatus(
    hasAccess: true,
    hasRecoveryKey: await service.hasRecoveryKey(),
    pendingDevices: await service.pendingDevices(),
  );
});

/// Short code users compare when approving this device from another one.
final currentDeviceFingerprintProvider = FutureProvider.autoDispose<String>((
  ref,
) async {
  final publicKey = await DeviceKeyService().initialize();

  return deviceFingerprint(publicKey);
});
