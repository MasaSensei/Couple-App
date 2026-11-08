import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/app_widgets.dart';

/// Every core component in one scrollable page. Used by the design-system
/// tests (layout + overflow across all themes) and the visual snapshots.
class ComponentGallery extends StatelessWidget {
  const ComponentGallery({super.key, this.compact = false});

  /// Smaller subset for the visual snapshots (fits one phone screen).
  final bool compact;

  static final _date = DateTime(2026, 11, 14, 19);

  Widget _photo(Color a, Color b) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [a, b],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final children = <Widget>[
      Row(
        children: [
          const CoupleAvatars(firstName: 'Raka', secondName: 'Nadia'),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Good evening, Raka', style: t.handwriting),
                Text('Raka & Nadia', style: t.display.copyWith(fontSize: 26)),
                Text('Together 412 days', style: t.caption),
              ],
            ),
          ),
        ],
      ),
      const SectionHeader(
        title: 'Next date',
        actionLabel: 'See all',
        onAction: _noop,
      ),
      JournalCard(
        ornament: true,
        onTap: () {},
        child: Row(
          children: [
            DateBadge(date: _date),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dinner at the corner café', style: t.heading),
                  const SizedBox(height: 2),
                  Text(AppFormatters.weekdayTime(_date), style: t.caption),
                  const SizedBox(height: AppSpacing.sm),
                  const StatusChip(
                    label: 'Planned',
                    tone: StatusTone.brand,
                    icon: Icons.event_available_rounded,
                    dense: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      SizedBox(
        height: 190,
        child: Row(
          children: [
            Expanded(
              child: PolaroidFrame(
                seed: 1,
                caption: 'sunset walk',
                trailing: '6 NOV',
                photo: _photo(const Color(0xFFF6B48A), const Color(0xFFC2577A)),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: PolaroidFrame(
                seed: 2,
                caption: 'rice terraces',
                photo: _photo(const Color(0xFF9FC3B0), const Color(0xFF4F7D6A)),
              ),
            ),
          ],
        ),
      ),
      const Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          StatusChip(
            label: 'Completed',
            tone: StatusTone.success,
            icon: Icons.check_rounded,
          ),
          StatusChip(
            label: 'Backup pending',
            tone: StatusTone.info,
            icon: Icons.schedule_rounded,
          ),
          StatusChip(
            label: 'Needs attention',
            tone: StatusTone.warning,
            icon: Icons.error_outline_rounded,
          ),
          StatusChip(
            label: 'Failed',
            tone: StatusTone.error,
            icon: Icons.close_rounded,
          ),
          StatusChip(label: 'Cancelled', tone: StatusTone.neutral),
        ],
      ),
      AppButton(
        label: 'Plan a date',
        icon: Icons.add_rounded,
        onPressed: () {},
      ),
      if (!compact) ...[
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Later',
                variant: AppButtonVariant.secondary,
                onPressed: () {},
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                label: 'Delete',
                variant: AppButtonVariant.destructive,
                onPressed: () {},
              ),
            ),
          ],
        ),
        const AppButton(label: 'Saving', isLoading: true, onPressed: null),
        SettingsGroup(
          title: 'Appearance',
          footer: 'Themes are shared by both of you.',
          children: [
            SettingsTile(
              icon: Icons.palette_outlined,
              title: 'Theme',
              value: 'Sakura',
              onTap: () {},
            ),
            SettingsTile(
              icon: Icons.motion_photos_off_outlined,
              title: 'Reduce motion',
              subtitle: 'This device only',
              trailing: Switch(value: true, onChanged: (_) {}),
            ),
            SettingsTile(
              icon: Icons.logout_rounded,
              title: 'Log out',
              destructive: true,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(
          height: 300,
          child: AppStateView.empty(
            title: 'No memories yet',
            message: 'Your little moments together will appear here.',
            actionLabel: 'Add a memory',
            onAction: _noop,
            illustration: SpotKind.camera,
          ),
        ),
        const SizedBox(
          height: 300,
          child: AppStateView.error(
            message: 'We could not load your dates.',
            onAction: _noop,
          ),
        ),
        const Row(
          children: [
            SkeletonBox(width: 56, height: 56),
            SizedBox(width: AppSpacing.smd),
            Expanded(child: SkeletonBox()),
          ],
        ),
      ],
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) => children[i],
    );
  }
}

void _noop() {}
