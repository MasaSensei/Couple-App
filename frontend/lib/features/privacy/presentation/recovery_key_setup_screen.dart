import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/security/encryption_errors.dart';
import 'package:frontend/core/security/secure_screen.dart';
import 'package:frontend/core/theme/app_spacing.dart';
import 'package:frontend/core/widgets/app_button.dart';
import 'package:frontend/features/memories/providers/memory_photo_provider.dart';
import 'package:frontend/features/privacy/providers/privacy_providers.dart';
import 'package:frontend/core/theme/app_theme_tokens.dart';

enum _Step { intro, reveal, verify, done }

/// First-time encryption setup: explains privacy, then generates a Recovery Key
/// the user must store and re-enter before it is saved (encrypted) on the server.
class RecoveryKeySetupScreen extends ConsumerStatefulWidget {
  const RecoveryKeySetupScreen({super.key});

  @override
  ConsumerState<RecoveryKeySetupScreen> createState() =>
      _RecoveryKeySetupScreenState();
}

class _RecoveryKeySetupScreenState
    extends ConsumerState<RecoveryKeySetupScreen> {
  static const _clipboardLifetime = Duration(seconds: 60);

  _Step _step = _Step.intro;
  String? _recoveryKey;
  bool _revealed = false;
  bool _confirmedStored = false;
  bool _busy = false;
  String? _error;
  Timer? _clipboardTimer;
  final _verifyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    SecureScreen.enable();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    _clipboardTimer?.cancel();
    _clearClipboardIfOurs();
    _verifyController.dispose();
    _recoveryKey = null;
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Make sure this device holds the Couple Key before backing it up.
      final status = await ref.read(encryptionStatusProvider.future);

      if (!status.hasAccess) {
        throw const CoupleKeyUnavailableException();
      }

      final key = await ref
          .read(coupleKeyProvisioningServiceProvider)
          .generateRecoveryKey();

      setState(() {
        _recoveryKey = key;
        _step = _Step.reveal;
      });
    } on CoupleKeyUnavailableException {
      setState(() => _error = EncryptionMessages.keyUnavailable);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _recoveryKey!));

    // Do not leave the key in the clipboard indefinitely.
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(_clipboardLifetime, _clearClipboardIfOurs);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied. The clipboard will be cleared in 1 minute.'),
      ),
    );
  }

  Future<void> _clearClipboardIfOurs() async {
    final key = _recoveryKey;
    if (key == null) return;

    final current = await Clipboard.getData(Clipboard.kTextPlain);
    if (current?.text == key) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  }

  String _normalize(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  Future<void> _verifyAndSave() async {
    if (_normalize(_verifyController.text) != _normalize(_recoveryKey!)) {
      setState(() => _error = "That doesn't match your recovery key.");
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(coupleKeyProvisioningServiceProvider)
          .saveRecoveryKey(_recoveryKey!);

      await _clearClipboardIfOurs();
      ref.invalidate(encryptionStatusProvider);

      setState(() {
        _recoveryKey = null;
        _step = _Step.done;
      });
    } catch (_) {
      setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Private photos')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...switch (_step) {
                _Step.intro => _intro(),
                _Step.reveal => _reveal(),
                _Step.verify => _verify(),
                _Step.done => _done(),
              },
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

  List<Widget> _intro() => [
    Text('Your memories are private ❤️', style: context.tokens.title),
    const SizedBox(height: AppSpacing.md),
    Text(
      'Photos are encrypted on your device before they are uploaded.\n\n'
      'That means our servers cannot read the photos you save here.\n\n'
      'Set up your recovery key so you can restore access if you lose '
      'your devices.',
      style: context.tokens.body,
    ),
    const SizedBox(height: AppSpacing.xl),
    AppButton(
      label: 'Generate Recovery Key',
      isLoading: _busy,
      onPressed: _generate,
    ),
  ];

  List<Widget> _reveal() => [
    Text('Your Private Recovery Key', style: context.tokens.title),
    const SizedBox(height: AppSpacing.md),
    Card(
      child: InkWell(
        onTap: () => setState(() => _revealed = true),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: _revealed
              ? Text(
                  _recoveryKey!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    height: 1.6,
                  ),
                )
              : const Text('Tap to reveal', textAlign: TextAlign.center),
        ),
      ),
    ),
    const SizedBox(height: AppSpacing.sm),
    OutlinedButton.icon(
      onPressed: _revealed ? _copy : null,
      icon: const Icon(Icons.copy_rounded),
      label: const Text('Copy'),
    ),
    const SizedBox(height: AppSpacing.md),
    Text(
      '⚠️ Keep this somewhere safe, like a password manager or on paper.\n\n'
      'We cannot read your private photos for you if you lose both your '
      'devices and your recovery key.',
      style: context.tokens.body,
    ),
    const SizedBox(height: AppSpacing.md),
    CheckboxListTile(
      value: _confirmedStored,
      onChanged: _revealed
          ? (value) => setState(() => _confirmedStored = value ?? false)
          : null,
      title: const Text('I have safely stored my recovery key.'),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    ),
    const SizedBox(height: AppSpacing.md),
    AppButton(
      label: 'Continue',
      onPressed: _confirmedStored
          ? () => setState(() {
              _revealed = false;
              _step = _Step.verify;
            })
          : null,
    ),
  ];

  List<Widget> _verify() => [
    Text('Check your recovery key', style: context.tokens.title),
    const SizedBox(height: AppSpacing.md),
    Text(
      'Enter the recovery key you saved to make sure it works.',
      style: context.tokens.body,
    ),
    const SizedBox(height: AppSpacing.md),
    TextField(
      controller: _verifyController,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.characters,
      maxLines: 3,
      minLines: 2,
      decoration: const InputDecoration(
        hintText: 'ABCD-EFGH-…',
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: AppSpacing.md),
    AppButton(label: 'Verify', isLoading: _busy, onPressed: _verifyAndSave),
    TextButton(
      onPressed: () => setState(() => _step = _Step.reveal),
      child: const Text('Show the key again'),
    ),
  ];

  List<Widget> _done() => [
    Text('All set ❤️', style: context.tokens.title),
    const SizedBox(height: AppSpacing.md),
    Text(
      'Your recovery key works. Keep it safe — you will only need it if you '
      'lose access on all your devices.',
      style: context.tokens.body,
    ),
    const SizedBox(height: AppSpacing.xl),
    AppButton(label: 'Done', onPressed: () => Navigator.of(context).pop(true)),
  ];
}
