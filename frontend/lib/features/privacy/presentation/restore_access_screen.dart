import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/security/encryption_errors.dart';
import 'package:frontend/core/security/secure_screen.dart';
import 'package:frontend/core/theme/app_spacing.dart';
import 'package:frontend/core/widgets/app_button.dart';
import 'package:frontend/features/memories/providers/memory_photo_provider.dart';
import 'package:frontend/features/privacy/providers/privacy_providers.dart';
import 'package:frontend/core/theme/app_theme_tokens.dart';

/// Shown when this device does not have the Couple Key: a new phone,
/// the partner's first device, or a reinstall. Two ways in: approval from a
/// device that has access, or the user's Recovery Key.
class RestoreAccessScreen extends ConsumerStatefulWidget {
  const RestoreAccessScreen({super.key});

  @override
  ConsumerState<RestoreAccessScreen> createState() =>
      _RestoreAccessScreenState();
}

class _RestoreAccessScreenState extends ConsumerState<RestoreAccessScreen> {
  final _recoveryController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    SecureScreen.enable();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    _recoveryController.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(memoryPhotoNotifierProvider.notifier).resetKeyCache();
    ref.invalidate(encryptionStatusProvider);
    Navigator.of(context).pop(true);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await action();
      if (mounted) _finish();
    } on CoupleKeyUnavailableException {
      setState(() => _error = 'This device has not been approved yet.');
    } on RecoveryUnavailableException {
      setState(() => _error = EncryptionMessages.recoveryUnavailable);
    } on FormatException {
      setState(() => _error = "That recovery key doesn't match.");
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkApproval() => _run(() async {
    final deviceIdentifier = await ref
        .read(deviceIdentityServiceProvider)
        .getOrCreateDeviceId();

    await ref
        .read(coupleKeyProvisioningServiceProvider)
        .provisionCurrentDevice(deviceIdentifier: deviceIdentifier);
  });

  Future<void> _restore() => _run(() async {
    final deviceIdentifier = await ref
        .read(deviceIdentityServiceProvider)
        .getOrCreateDeviceId();

    await ref
        .read(coupleKeyProvisioningServiceProvider)
        .restoreWithRecoveryKey(
          deviceIdentifier: deviceIdentifier,
          recoveryKeyText: _recoveryController.text,
        );

    _recoveryController.clear();
  });

  @override
  Widget build(BuildContext context) {
    final fingerprint = ref.watch(currentDeviceFingerprintProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Unlock private photos')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                EncryptionMessages.keyUnavailable,
                style: context.tokens.body,
              ),
              const SizedBox(height: AppSpacing.xl),

              Text('Approve from another device', style: context.tokens.title),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Open the app on a device that already shows your photos '
                '(yours or your partner\'s), go to My Devices and approve this '
                'device. Make sure it shows this code:',
                style: context.tokens.body,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  fingerprint.value ?? '…',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 20,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: _busy ? null : _checkApproval,
                child: const Text("I've approved it"),
              ),

              const SizedBox(height: AppSpacing.xl),

              Text('Use your recovery key', style: context.tokens.title),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _recoveryController,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'ABCD-EFGH-…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Restore access',
                isLoading: _busy,
                onPressed: _restore,
              ),

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: context.tokens.body.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
