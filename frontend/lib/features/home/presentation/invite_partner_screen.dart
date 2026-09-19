import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../providers/couple_invitation_providers.dart';
import '../providers/couple_invitation_state.dart';

class InvitePartnerScreen extends ConsumerStatefulWidget {
  const InvitePartnerScreen({super.key});

  @override
  ConsumerState<InvitePartnerScreen> createState() =>
      _InvitePartnerScreenState();
}

class _InvitePartnerScreenState extends ConsumerState<InvitePartnerScreen> {
  Future<void> _createInvitation() async {
    await ref
        .read(coupleInvitationNotifierProvider.notifier)
        .createInvitation();
  }

  Future<void> _copyToken(String token) async {
    await Clipboard.setData(ClipboardData(text: token));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Invitation code copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(coupleInvitationNotifierProvider);

    final isLoading = state.status == CoupleInvitationStatus.loading;

    final invitation = state.invitation;

    return Scaffold(
      appBar: AppBar(title: const Text('Invite your partner')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite_rounded, size: 64),

                  const SizedBox(height: AppSpacing.lg),

                  Text(
                    'Invite your partner ♡',
                    style: AppTextStyles.title,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  Text(
                    'Create an invitation and share it '
                    'with your partner.',
                    style: AppTextStyles.subtitle,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  if (invitation != null) ...[
                    _buildInvitationCard(invitation.token),

                    const SizedBox(height: AppSpacing.lg),
                  ],

                  AppButton(
                    label: invitation == null
                        ? 'Create invitation'
                        : 'Create another invitation',
                    onPressed: isLoading ? null : _createInvitation,
                    isLoading: isLoading,
                  ),

                  if (state.status == CoupleInvitationStatus.error) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      state.errorMessage ?? 'Unable to create invitation.',
                      style: AppTextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvitationCard(String? token) {
    if (token == null || token.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const Text('Your invitation code'),

            const SizedBox(height: AppSpacing.md),

            SelectableText(
              token,
              textAlign: TextAlign.center,
              style: AppTextStyles.title,
            ),

            const SizedBox(height: AppSpacing.md),

            OutlinedButton.icon(
              onPressed: () => _copyToken(token),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy code'),
            ),
          ],
        ),
      ),
    );
  }
}
