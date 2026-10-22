import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/security/couple/couple_device.dart';
import 'package:frontend/core/security/device_fingerprint.dart';
import 'package:frontend/features/device/providers/device_provider.dart';
import 'package:frontend/features/memories/providers/memory_photo_provider.dart';
import 'package:frontend/features/privacy/providers/privacy_providers.dart';

class DeviceManagementScreen extends ConsumerWidget {
  const DeviceManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Devices')),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(
            'Failed to load devices.\n$error',
            textAlign: TextAlign.center,
          ),
        ),
        data: (devices) {
          if (devices.isEmpty) {
            return const Center(child: Text('No registered devices.'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(devicesProvider);
              await ref.read(devicesProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: devices.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return const _AccessSection();

                final device = devices[index - 1];

                final isRevoked = device.revokedAt != null;

                return Card(
                  child: ListTile(
                    leading: Icon(
                      device.platform == 'android'
                          ? Icons.phone_android
                          : Icons.phone_iphone,
                    ),
                    title: Text(device.deviceName ?? 'Unknown Device'),
                    subtitle: Text(
                      '${device.platform.toUpperCase()}\n'
                      '${isRevoked ? 'Revoked' : 'Active'}',
                    ),
                    isThreeLine: true,
                    trailing: isRevoked
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.block),
                            tooltip: 'Revoke device',
                            onPressed: () async {
                              final shouldRevoke = await showDialog<bool>(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text('Revoke device?'),
                                    content: Text(
                                      '${device.deviceName ?? 'This device'} '
                                      'will be signed out and can no longer '
                                      'download your photos.\n\n'
                                      'Photos already opened on it cannot be '
                                      'erased remotely.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop(false);
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () {
                                          Navigator.of(context).pop(true);
                                        },
                                        child: const Text('Revoke'),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (shouldRevoke != true || !context.mounted) {
                                return;
                              }

                              try {
                                final repository = ref.read(
                                  deviceRepositoryProvider,
                                );

                                await repository.revokeDevice(device.id);

                                ref.invalidate(devicesProvider);
                                ref.invalidate(encryptionStatusProvider);
                              } catch (error) {
                                if (!context.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to revoke device: $error',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// This device's code, plus devices waiting for this device to share the key.
class _AccessSection extends ConsumerWidget {
  const _AccessSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fingerprint = ref.watch(currentDeviceFingerprintProvider).value;
    final pending =
        ref.watch(encryptionStatusProvider).value?.pendingDevices ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('This device'),
            subtitle: Text('Code: ${fingerprint ?? '…'}'),
          ),
        ),
        for (final device in pending)
          Card(
            child: ListTile(
              leading: const Icon(Icons.hourglass_top_rounded),
              title: Text(device.deviceName ?? 'New device'),
              subtitle: Text(
                device.isMine
                    ? 'Your device is waiting for access'
                    : "Your partner's device is waiting for access",
              ),
              trailing: FilledButton(
                onPressed: () => _approve(context, ref, device),
                child: const Text('Approve'),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    CoupleDevice device,
  ) async {
    final code = await deviceFingerprint(device.publicKey);

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve this device?'),
        content: Text(
          'Only approve if the other device shows exactly this code:\n\n'
          '$code\n\n'
          'It will be able to open all your private photos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Codes match'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(coupleKeyProvisioningServiceProvider).authorizeDevice(device);
      ref.invalidate(encryptionStatusProvider);
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not approve. Please try again.')),
      );
    }
  }
}
