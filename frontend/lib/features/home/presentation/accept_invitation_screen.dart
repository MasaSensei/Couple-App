import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/app_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/couple_invitation_providers.dart';
import '../providers/couple_invitation_state.dart';

class AcceptInvitationScreen extends ConsumerStatefulWidget {
  const AcceptInvitationScreen({super.key});

  @override
  ConsumerState<AcceptInvitationScreen> createState() =>
      _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState
    extends ConsumerState<AcceptInvitationScreen> {
  final _tokenController = TextEditingController();

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _acceptInvitation() async {
    final token = _tokenController.text.trim();

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an invitation token.')),
      );

      return;
    }

    await ref
        .read(coupleInvitationNotifierProvider.notifier)
        .acceptInvitation(token);

    if (!mounted) {
      return;
    }

    final state = ref.read(coupleInvitationNotifierProvider);

    if (state.status == CoupleInvitationStatus.accepted) {
      Navigator.of(context).pop(true);
      return;
    }

    if (state.errorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(state.errorMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(coupleInvitationNotifierProvider);

    final isLoading = state.status == CoupleInvitationStatus.loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Accept invitation')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),

              Text('Join your little space', style: context.tokens.title),

              const SizedBox(height: AppSpacing.sm),

              Text(
                'Enter the invitation token shared by your partner.',
                style: context.tokens.subtitle,
              ),

              const SizedBox(height: AppSpacing.xl),

              AppTextField(
                controller: _tokenController,
                label: 'Invitation token',
                hint: 'Paste your invitation token',
              ),

              const SizedBox(height: AppSpacing.lg),

              AppButton(
                label: 'Accept invitation',
                onPressed: isLoading ? null : _acceptInvitation,
                isLoading: isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
