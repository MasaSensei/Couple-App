import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../providers/couple_providers.dart';

class JoinCoupleScreen extends ConsumerStatefulWidget {
  const JoinCoupleScreen({super.key});

  @override
  ConsumerState<JoinCoupleScreen> createState() => _JoinCoupleScreenState();
}

class _JoinCoupleScreenState extends ConsumerState<JoinCoupleScreen> {
  final _inviteCodeController = TextEditingController();

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _joinCouple() async {
    final inviteCode = _inviteCodeController.text.trim();

    if (inviteCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an invite code.')),
      );
      return;
    }

    await ref
        .read(coupleNotifierProvider.notifier)
        .joinCouple(inviteCode: inviteCode);

    if (!mounted) {
      return;
    }

    final state = ref.read(coupleNotifierProvider);

    if (state.status.name == 'loaded') {
      Navigator.of(context).pop();
    } else if (state.message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(state.message!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(coupleNotifierProvider);
    final isLoading = state.status.name == 'loading';

    return Scaffold(
      appBar: AppBar(title: const Text('Join a space')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),

              Text('Join your little space ♡', style: AppTextStyles.title),

              const SizedBox(height: AppSpacing.sm),

              Text(
                'Enter the invite code shared by your partner.',
                style: AppTextStyles.subtitle,
              ),

              const SizedBox(height: AppSpacing.xl),

              AppTextField(
                controller: _inviteCodeController,
                label: 'Invite code',
                hint: 'Example: TBEWCRTQ',
              ),

              const SizedBox(height: AppSpacing.lg),

              AppButton(
                label: 'Join space',
                onPressed: isLoading ? null : _joinCouple,
                isLoading: isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
