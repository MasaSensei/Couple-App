import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/device/data/presentation/screens/device_management_screen.dart';
import 'package:frontend/features/privacy/presentation/recovery_key_setup_screen.dart';
import 'package:frontend/features/privacy/presentation/restore_access_screen.dart';
import 'package:frontend/features/privacy/providers/privacy_providers.dart';

/// Home prompt for the only encryption steps that need the user:
/// unlocking this device, approving a waiting device, or setting up recovery.
class EncryptionStatusBanner extends ConsumerWidget {
  const EncryptionStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(encryptionStatusProvider).value;

    if (status == null) return const SizedBox.shrink();

    final (icon, text, Widget screen) = switch (status) {
      EncryptionStatus(hasAccess: false) => (
        Icons.lock_outline_rounded,
        'Unlock your private photos on this device',
        const RestoreAccessScreen(),
      ),
      EncryptionStatus(pendingDevices: [_, ...]) => (
        Icons.devices_rounded,
        'A device is waiting for access to your private photos',
        const DeviceManagementScreen(),
      ),
      EncryptionStatus(hasRecoveryKey: false) => (
        Icons.key_rounded,
        'Set up your recovery key',
        const RecoveryKeySetupScreen(),
      ),
      _ => (null, null, const SizedBox.shrink()),
    };

    if (icon == null) return const SizedBox.shrink();

    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(text!),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => screen));
          ref.invalidate(encryptionStatusProvider);
        },
      ),
    );
  }
}
