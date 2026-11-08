import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_registry.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../account/presentation/account_screen.dart';
import '../../appearance/presentation/theme_gallery_screen.dart';
import '../../appearance/providers/appearance_controller.dart';
import '../../auth/providers/auth_providers.dart';
import '../../device/data/presentation/screens/device_management_screen.dart';
import '../../home/presentation/invite_partner_screen.dart';
import '../../home/providers/couple_providers.dart';
import '../../photo_booth/presentation/open_photo_booth.dart';
import '../../privacy/presentation/recovery_key_setup_screen.dart';
import '../../subscription/presentation/storage_screen.dart';
import '../../subscription/presentation/subscription_overview_screen.dart';

/// Profile & settings: everything that used to be scattered over the home
/// app bar and button list, grouped by what people look for.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Future<void> _editAnniversary(BuildContext context, WidgetRef ref) async {
    final couple = ref.read(coupleNotifierProvider).couple;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: couple?.relationshipStartedAt ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'When did your story start?',
    );
    if (picked == null || !context.mounted) return;

    final error = await ref
        .read(coupleNotifierProvider.notifier)
        .updateRelationshipStart(picked);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Anniversary saved for both of you.')),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'Log out?',
      message: 'Your memories stay safe. You will need your password to log back in on this device.',
      confirmLabel: 'Log out',
    );
    if (confirmed) await ref.read(authNotifierProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final user = ref.watch(authNotifierProvider.select((s) => s.user));
    final couple = ref.watch(coupleNotifierProvider.select((s) => s.couple));
    final themeKey = ref.watch(
      appearanceControllerProvider.select((s) => s.settings.themeKey),
    );

    final partner = couple?.members.where((m) => m.id != user?.id).firstOrNull;
    final anniversary = couple?.relationshipStartedAt;

    return AppScaffold(
      title: 'Me',
      padded: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          Row(
            children: [
              CoupleAvatars(
                firstName: user?.name ?? '?',
                secondName: partner?.name,
                size: 52,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name ?? '', style: t.title),
                    if (user?.email != null)
                      Text(user!.email, style: t.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          SettingsGroup(
            title: 'Our couple',
            children: [
              if (partner != null)
                SettingsTile(
                  icon: Icons.favorite_border_rounded,
                  title: partner.name,
                  subtitle: 'Your partner',
                )
              else
                SettingsTile(
                  icon: Icons.mail_outline_rounded,
                  title: 'Invite your partner',
                  subtitle: 'Your space is ready for two',
                  onTap: () => _push(context, const InvitePartnerScreen()),
                ),
              SettingsTile(
                icon: Icons.cake_outlined,
                title: 'Anniversary',
                subtitle: 'Shown on your home as "Together N days"',
                value: anniversary == null
                    ? 'Not set'
                    : AppFormatters.dayMonthYear(anniversary),
                onTap: couple == null
                    ? null
                    : () => _editAnniversary(context, ref),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          SettingsGroup(
            title: 'Appearance',
            footer:
                'Themes are shared by both of you. Motion and light/dark '
                'mode are set per device in Themes.',
            children: [
              SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Themes',
                value: ThemeRegistry.byKey(themeKey).name,
                onTap: () => _push(context, const ThemeGalleryScreen()),
              ),
              SettingsTile(
                icon: Icons.photo_camera_back_outlined,
                title: 'Photo Booth',
                onTap: () => openPhotoBooth(context, ref),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          SettingsGroup(
            title: 'Plan & storage',
            children: [
              SettingsTile(
                icon: Icons.workspace_premium_outlined,
                title: 'Subscription',
                onTap: () => _push(context, const SubscriptionOverviewScreen()),
              ),
              SettingsTile(
                icon: Icons.cloud_outlined,
                title: 'Storage',
                onTap: () => _push(context, const StorageScreen()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          SettingsGroup(
            title: 'Privacy & security',
            footer:
                'Photos are encrypted on your devices. Nobody else, '
                'including us, can open them.',
            children: [
              SettingsTile(
                icon: Icons.key_outlined,
                title: 'Recovery key',
                subtitle: 'Get your photos back on a new phone',
                onTap: () => _push(context, const RecoveryKeySetupScreen()),
              ),
              SettingsTile(
                icon: Icons.devices_rounded,
                title: 'My devices',
                onTap: () => _push(context, const DeviceManagementScreen()),
              ),
              SettingsTile(
                icon: Icons.manage_accounts_outlined,
                title: 'Account & data',
                subtitle: 'Export or delete your data',
                onTap: () => _push(context, const AccountScreen()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          SettingsGroup(
            title: 'Support',
            children: [
              SettingsTile(
                icon: Icons.description_outlined,
                title: 'Licenses',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Our Little Space',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Log out',
                destructive: true,
                onTap: () => _logout(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
