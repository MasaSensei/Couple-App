import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/home/presentation/accept_invitation_screen.dart';
import 'package:frontend/features/home/presentation/invite_partner_screen.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/couple_providers.dart';
import '../providers/couple_state.dart';
import 'date_list_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(
      () => ref.read(coupleNotifierProvider.notifier).loadCouple(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final coupleState = ref.watch(coupleNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Our Little Space'),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(authNotifierProvider.notifier).logout();
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _buildContent(authState.user?.name, coupleState),
        ),
      ),
    );
  }

  Widget _buildContent(String? userName, CoupleState coupleState) {
    switch (coupleState.status) {
      case CoupleStatus.initial:
      case CoupleStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case CoupleStatus.loaded:
        return _buildCoupleContent(userName, coupleState);

      case CoupleStatus.empty:
        return _buildEmptyCouple();

      case CoupleStatus.error:
        return _buildError(coupleState.errorMessage);
    }
  }

  Widget _buildCoupleContent(String? userName, CoupleState state) {
    final couple = state.couple;

    if (couple == null) {
      return _buildError('Couple data is unavailable.');
    }

    final partner = couple.members.length > 1
        ? couple.members.firstWhere(
            (member) => member.name != userName,
            orElse: () => couple.members.first,
          )
        : null;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_rounded, size: 64),

            const SizedBox(height: AppSpacing.lg),

            Text(
              'Hello, ${userName ?? 'there'} ♡',
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.sm),

            Text(
              'Your couple space is ready.',
              style: AppTextStyles.subtitle,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.xl),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    const Icon(Icons.people_alt_rounded, size: 32),

                    const SizedBox(height: AppSpacing.md),

                    Text(
                      '${couple.members.length} member(s)',
                      style: AppTextStyles.subtitle,
                    ),

                    if (partner != null) ...[
                      const SizedBox(height: AppSpacing.md),

                      Text(
                        partner.name,
                        style: AppTextStyles.title,
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: AppSpacing.xs),

                      Text(
                        partner.email,
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DateListScreen()),
                );
              },
              icon: const Icon(Icons.favorite_outline_rounded),
              label: const Text('Our Dates'),
            ),

            if (couple.members.length < 2) ...[
              const SizedBox(height: AppSpacing.lg),

              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const InvitePartnerScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.favorite_border_rounded),
                label: const Text('Invite your partner'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCouple() {
    final isLoading =
        ref.watch(coupleNotifierProvider).status == CoupleStatus.loading;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_border_rounded, size: 64),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Your little space is waiting ♡',
            style: AppTextStyles.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Create a private space for the two of you.',
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: isLoading
                ? null
                : () {
                    ref.read(coupleNotifierProvider.notifier).createCouple();
                  },
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Create our space'),
          ),

          const SizedBox(height: AppSpacing.sm),

          OutlinedButton(
            onPressed: isLoading
                ? null
                : () async {
                    final accepted = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const AcceptInvitationScreen(),
                      ),
                    );

                    if (accepted == true && mounted) {
                      await ref
                          .read(coupleNotifierProvider.notifier)
                          .loadCouple();
                    }
                  },
            child: const Text('Accept invitation'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String? message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 56),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Something went wrong',
            style: AppTextStyles.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message ?? 'Unable to load your couple.',
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () {
              ref.read(coupleNotifierProvider.notifier).loadCouple();
            },
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
