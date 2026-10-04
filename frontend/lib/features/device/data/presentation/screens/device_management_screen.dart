import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/device/providers/device_provider.dart';

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
              itemCount: devices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final device = devices[index];

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
                                      'You will no longer be able to use '
                                      '${device.deviceName ?? 'this device'} '
                                      'for encrypted data access.',
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
