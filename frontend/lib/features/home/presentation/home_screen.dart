import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/device/data/presentation/screens/device_management_screen.dart';
import 'package:frontend/features/home/presentation/accept_invitation_screen.dart';
import 'package:frontend/features/home/presentation/invite_partner_screen.dart';
import 'package:frontend/features/memories/presentation/screens/memory_list_screen.dart';
import 'package:frontend/features/privacy/presentation/encryption_status_banner.dart';

import '../../../core/theme/app_spacing.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/couple_providers.dart';
import '../providers/couple_state.dart';
import 'date_list_screen.dart';
import 'package:frontend/core/theme/app_theme_tokens.dart';
import 'package:frontend/core/theme/theme_customization.dart';
import 'package:frontend/core/theme/theme_decorations.dart';
import 'package:frontend/features/appearance/presentation/partner_theme_banner.dart';
import 'package:frontend/features/appearance/presentation/theme_gallery_screen.dart';
import 'package:frontend/features/appearance/providers/appearance_controller.dart';
import 'package:frontend/features/photo_booth/presentation/photo_booth_screen.dart';

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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ThemeGalleryScreen()),
            ),
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Themes',
          ),
          IconButton(
            onPressed: () {
              ref.read(authNotifierProvider.notifier).logout();
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: ThemedBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _buildContent(authState.user?.name, coupleState),
          ),
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
            const PartnerThemeBanner(),

            ..._buildGreeting(userName, partner?.name),

            const SizedBox(height: AppSpacing.sm),

            Text(
              'Your couple space is ready.',
              style: context.tokens.subtitle,
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
                      style: context.tokens.subtitle,
                    ),

                    if (partner != null) ...[
                      const SizedBox(height: AppSpacing.md),

                      Text(
                        partner.name,
                        style: context.tokens.title,
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: AppSpacing.xs),

                      Text(
                        partner.email,
                        style: context.tokens.body,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            const EncryptionStatusBanner(),

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

            const SizedBox(height: AppSpacing.md),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MemoryListScreen()),
                );
              },
              icon: const Icon(Icons.photo_album_outlined),
              label: const Text('Our Memories'),
            ),

            const SizedBox(height: AppSpacing.md),

            OutlinedButton.icon(
              onPressed: () {
                final catalog = ref.read(appearanceControllerProvider).catalog;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PhotoBoothScreen(
                      // Offline / not loaded yet: all built-in layouts.
                      availableTemplates: catalog?.photoBoothTemplates.map((t) => t.key).toSet(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.photo_camera_back_outlined),
              label: const Text('Photo Booth'),
            ),

            const SizedBox(height: AppSpacing.md),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DeviceManagementScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.devices_rounded),
              label: const Text('My Devices'),
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

  /// The greeting follows the couple's chosen Couple Space style.
  List<Widget> _buildGreeting(String? userName, String? partnerName) {
    final t = context.tokens;
    final hello = 'Hello, ${userName ?? 'there'} ♡';

    return switch (t.coupleSpaceStyle) {
      CoupleSpaceStyle.classic => [
          Icon(Icons.favorite_rounded, size: 64, color: t.primary),
          const SizedBox(height: AppSpacing.lg),
          Text(hello, style: t.title, textAlign: TextAlign.center),
        ],
      CoupleSpaceStyle.cozy => [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(color: t.secondary.withValues(alpha: 0.35), shape: BoxShape.circle),
            child: Icon(Icons.favorite_rounded, size: 56, color: t.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            partnerName == null ? hello : '${userName ?? 'You'} & $partnerName',
            style: t.display.copyWith(fontSize: 30),
            textAlign: TextAlign.center,
          ),
        ],
      CoupleSpaceStyle.minimal => [
          Text(hello, style: t.title, textAlign: TextAlign.center),
        ],
    };
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
            style: context.tokens.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Create a private space for the two of you.',
            style: context.tokens.subtitle,
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
            style: context.tokens.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message ?? 'Unable to load your couple.',
            style: context.tokens.subtitle,
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
