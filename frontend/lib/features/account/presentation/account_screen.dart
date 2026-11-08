import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/app_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/providers/auth_dependencies.dart';
import '../../auth/providers/auth_providers.dart';

/// Account & data: export (data portability) and permanent account deletion
/// (App Store 5.1.1(v) / Google Play account-deletion requirement).
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final data = await ref.read(authRepositoryProvider).exportData();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final file = XFile.fromData(
        utf8.encode(json),
        mimeType: 'application/json',
        name: 'our-little-space-export.json',
      );

      await SharePlus.instance.share(
        ShareParams(files: [file], subject: 'My data export'),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(_message(error))));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _delete() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const DeleteAccountDialog(),
    );
    if (password == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .deleteAccount(password: password);
      // The router listens to the auth state and returns to the login screen.
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Something went wrong. Please try again.';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Account & data',
      padded: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          SettingsGroup(
            title: 'Your data',
            footer:
                'Your profile, dates, memories, comments and devices as a JSON file. '
                'Photos stay encrypted on our servers; open a photo and save it to keep a decrypted copy.',
            children: [
              SettingsTile(
                icon: Icons.download_outlined,
                title: 'Export my data',
                trailing: _exporting ? const AppLoading(size: 20) : null,
                onTap: _exporting ? null : _export,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsGroup(
            title: 'Danger zone',
            footer: 'Permanently delete your account and personal data.',
            children: [
              SettingsTile(
                key: const Key('delete-account'),
                icon: Icons.delete_forever_outlined,
                title: 'Delete account',
                destructive: true,
                onTap: _delete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Explains exactly what happens, then asks for the password. Returns it, or null.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _understood = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = _understood && _password.text.isNotEmpty;

    return AlertDialog(
      title: const Text('Delete your account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '• Your profile, devices, keys on our server, recovery package and your comments are deleted now.\n'
              '• If your partner is still in your space, the shared memories, photos and dates stay with them, '
              'without your name.\n'
              '• If you are the last member, all memories and photos are deleted. Encrypted copies are removed '
              'from storage and backups within about 60 days.\n'
              '• A store subscription must be cancelled in the App Store / Google Play; deleting the account does not stop it.\n'
              '• This cannot be undone.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('delete-account-password'),
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password'),
              onChanged: (_) => setState(() {}),
            ),
            CheckboxListTile(
              key: const Key('delete-account-confirm'),
              contentPadding: EdgeInsets.zero,
              value: _understood,
              onChanged: (value) =>
                  setState(() => _understood = value ?? false),
              title: const Text('I understand this is permanent'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('delete-account-submit'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: canDelete
              ? () => Navigator.of(context).pop(_password.text)
              : null,
          child: const Text('Delete account'),
        ),
      ],
    );
  }
}
