import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/couple_providers.dart';
import '../providers/couple_state.dart';
import 'join_couple_screen.dart';

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
        return _buildError(coupleState.message);
    }
  }

  Widget _buildCoupleContent(String? userName, CoupleState state) {
    final couple = state.couple;

    if (couple == null) {
      return _buildError('Couple data is unavailable.');
    }

    return Center(
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
          const SizedBox(height: AppSpacing.lg),
          Text('${couple.members.length} member(s)', style: AppTextStyles.body),
        ],
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
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const JoinCoupleScreen(),
                      ),
                    );
                  },
            child: const Text('Join a space'),
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
