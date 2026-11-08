import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_customization.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../appearance/presentation/partner_theme_banner.dart';
import '../../appearance/presentation/theme_gallery_screen.dart';
import '../../auth/data/models/couple_model.dart';
import '../../auth/data/models/user_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../../memories/data/models/memory_model.dart';
import '../../memories/presentation/screens/memory_detail_screen.dart';
import '../../memories/presentation/widgets/memory_cover.dart';
import '../../memories/providers/memory_providers.dart';
import '../../memories/providers/memory_state.dart';
import '../../photo_booth/presentation/open_photo_booth.dart';
import '../../privacy/presentation/encryption_status_banner.dart';
import '../data/models/date_model.dart';
import '../providers/couple_providers.dart';
import '../providers/couple_state.dart';
import '../providers/date_providers.dart';
import '../providers/date_state.dart';
import 'accept_invitation_screen.dart';
import 'date_detail_screen.dart';
import 'date_form_screen.dart';
import 'invite_partner_screen.dart';
import 'widgets/date_status_chip.dart';

/// Couple Space: who we are, what's next, what we remember.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCouple);
  }

  Future<void> _loadCouple() async {
    await ref.read(coupleNotifierProvider.notifier).loadCouple();
    if (!mounted) return;
    if (ref.read(coupleNotifierProvider).status == CoupleStatus.loaded) {
      // Shared with the Dates and Memories tabs; load once if not yet loaded.
      if (ref.read(dateNotifierProvider).status == DateStatus.initial) {
        ref.read(dateNotifierProvider.notifier).loadDates();
      }
      if (ref.read(memoryNotifierProvider).status == MemoryStatus.initial) {
        ref.read(memoryNotifierProvider.notifier).loadTimeline();
      }
    }
  }

  Future<void> _refresh() => Future.wait([
    ref.read(coupleNotifierProvider.notifier).loadCouple(),
    ref.read(dateNotifierProvider.notifier).loadDates(),
    ref.read(memoryNotifierProvider.notifier).loadTimeline(),
  ]);

  @override
  Widget build(BuildContext context) {
    final coupleState = ref.watch(coupleNotifierProvider);

    return AppScaffold(
      decorated: true,
      padded: false,
      body: SafeArea(
        bottom: false,
        child: switch (coupleState.status) {
          CoupleStatus.initial ||
          CoupleStatus.loading => const AppStateView.loading(),
          CoupleStatus.empty => _Onboarding(onJoined: _loadCouple),
          CoupleStatus.error => AppStateView.error(
            message:
                coupleState.errorMessage ?? 'We could not open your space.',
            onAction: _loadCouple,
          ),
          CoupleStatus.loaded =>
            coupleState.couple == null
                ? AppStateView.error(onAction: _loadCouple)
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: _CoupleSpace(couple: coupleState.couple!),
                  ),
        },
      ),
    );
  }
}

class _CoupleSpace extends ConsumerWidget {
  const _CoupleSpace({required this.couple});

  final CoupleModel couple;

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authNotifierProvider.select((s) => s.user));
    final dates = ref.watch(dateNotifierProvider);
    final memories = ref.watch(memoryNotifierProvider);
    final partner = couple.members.where((m) => m.id != me?.id).firstOrNull;

    final now = DateTime.now();
    final upcoming =
        dates.dates
            .where((d) => DateStatusStyle.isUpcoming(d, now: now))
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: [
        _Header(couple: couple, me: me, partner: partner),
        const SizedBox(height: AppSpacing.lg),

        const PartnerThemeBanner(),
        const EncryptionStatusBanner(),
        if (partner == null) ...[
          _InviteCard(onTap: () => _push(context, const InvitePartnerScreen())),
          const SizedBox(height: AppSpacing.lg),
        ],

        SectionHeader(
          title: 'Next date',
          actionLabel: upcoming.length > 1 ? 'See all' : null,
          onAction: () => context.go('/dates'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _NextDate(state: dates, next: upcoming.firstOrNull, now: now),
        const SizedBox(height: AppSpacing.lg),

        SectionHeader(
          title: 'From our journal',
          actionLabel: memories.memories.isEmpty ? null : 'See all',
          onAction: () => context.go('/memories'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _JournalStrip(state: memories),
        const SizedBox(height: AppSpacing.lg),

        const _QuickActions(),
        const SizedBox(height: AppSpacing.lg),

        _RecentActivity(
          dates: dates.dates,
          memories: memories.memories,
          couple: couple,
          me: me,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.couple,
    required this.me,
    required this.partner,
  });

  final CoupleModel couple;
  final UserModel? me;
  final UserModel? partner;

  static String greeting(DateTime now) => switch (now.hour) {
    < 5 => 'Sweet dreams',
    < 12 => 'Good morning',
    < 18 => 'Good afternoon',
    _ => 'Good evening',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = me?.name ?? 'there';
    final firstName = name.split(' ').first;
    final now = DateTime.now();

    final since = couple.relationshipStartedAt;
    final subtitle = since != null
        ? 'Together ${AppFormatters.daysBetween(since, now) + 1} days · since ${AppFormatters.dayMonthYear(since)}'
        : couple.createdAt != null
        ? 'Our space since ${AppFormatters.monthYear(couple.createdAt!)}'
        : null;

    final names = partner == null
        ? '$firstName\'s space'
        : '$firstName & ${partner!.name.split(' ').first}';

    final style = t.coupleSpaceStyle;
    final titleStyle = switch (style) {
      CoupleSpaceStyle.cozy => t.display.copyWith(fontSize: 34),
      CoupleSpaceStyle.classic => t.display.copyWith(fontSize: 28),
      CoupleSpaceStyle.minimal => t.title,
    };

    final content = Column(
      crossAxisAlignment: style == CoupleSpaceStyle.cozy
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (style != CoupleSpaceStyle.minimal)
          Text('${greeting(now)}, $firstName', style: t.handwriting),
        Semantics(
          header: true,
          child: Text(
            names,
            style: titleStyle,
            textAlign: style == CoupleSpaceStyle.cozy ? TextAlign.center : null,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(subtitle, style: t.caption),
        ],
      ],
    );

    final avatars = CoupleAvatars(
      firstName: name,
      secondName: partner?.name,
      size: style == CoupleSpaceStyle.cozy ? 56 : 44,
    );

    if (style == CoupleSpaceStyle.cozy) {
      return JournalCard(
        color: Color.alphaBlend(
          t.secondary.withValues(alpha: t.isDark ? 0.35 : 0.45),
          t.surface,
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            avatars,
            const SizedBox(height: AppSpacing.md),
            content,
          ],
        ),
      );
    }

    return Row(
      children: [
        avatars,
        const SizedBox(width: AppSpacing.md),
        Expanded(child: content),
      ],
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return JournalCard(
      ornament: true,
      child: Row(
        children: [
          const SpotIllustration(kind: SpotKind.envelope, size: 72),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your space is ready for two', style: t.heading),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Send your partner an invitation to share dates and memories.',
                  style: t.caption,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Invite your partner',
                  expand: false,
                  onPressed: onTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextDate extends StatelessWidget {
  const _NextDate({required this.state, required this.next, required this.now});

  final DateState state;
  final DateModel? next;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (next == null &&
        (state.status == DateStatus.initial ||
            state.status == DateStatus.loading)) {
      return const Row(
        children: [
          SkeletonBox(width: 56, height: 64),
          SizedBox(width: AppSpacing.smd),
          Expanded(child: SkeletonBox(height: 40)),
        ],
      );
    }

    if (state.status == DateStatus.error && next == null) {
      return JournalCard(
        child: Text(
          'We could not load your dates. Pull down to try again.',
          style: t.caption,
        ),
      );
    }

    final date = next;
    if (date == null) {
      return JournalCard(
        onTap: () => Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute(builder: (_) => const DateFormScreen())),
        child: Row(
          children: [
            const SpotIllustration(kind: SpotKind.calendar, size: 64),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nothing planned yet', style: t.heading),
                  const SizedBox(height: 2),
                  Text('Plan your next little adventure.', style: t.caption),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline_rounded, color: t.primary),
          ],
        ),
      );
    }

    final where = [
      AppFormatters.weekdayTime(date.scheduledAt),
      ?date.location,
    ].join(' · ');

    return JournalCard(
      ornament: true,
      ornamentSeed: date.id,
      semanticLabel:
          'Next date: ${date.title}, ${AppFormatters.full(date.scheduledAt)}, '
          '${AppFormatters.relativeDays(date.scheduledAt, now: now)}',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DateDetailScreen(dateId: date.id)),
      ),
      child: Row(
        children: [
          DateBadge(date: date.scheduledAt),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date.title,
                  style: t.heading,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  where,
                  style: t.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                StatusChip(
                  label: AppFormatters.relativeDays(date.scheduledAt, now: now),
                  tone: StatusTone.brand,
                  icon: Icons.schedule_rounded,
                  dense: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalStrip extends StatelessWidget {
  const _JournalStrip({required this.state});

  final MemoryState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final recent = state.memories.take(6).toList();

    if (recent.isEmpty &&
        (state.status == MemoryStatus.initial ||
            state.status == MemoryStatus.loading)) {
      return const SizedBox(
        height: 168,
        child: Row(
          children: [
            SkeletonBox(width: 128, height: 160),
            SizedBox(width: AppSpacing.md),
            SkeletonBox(width: 128, height: 160),
          ],
        ),
      );
    }

    if (recent.isEmpty) {
      return JournalCard(
        onTap: () => context.push('/memories/create'),
        child: Row(
          children: [
            const SpotIllustration(kind: SpotKind.camera, size: 64),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Start your journal', style: t.heading),
                  const SizedBox(height: 2),
                  Text(
                    'Save a moment with photos and a few words.',
                    style: t.caption,
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline_rounded, color: t.primary),
          ],
        ),
      );
    }

    // Height grows with the caption font so large text never clips.
    final captionHeight = MediaQuery.textScalerOf(context).scale(26);
    return SizedBox(
      height: 128 + 24 + captionHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        itemCount: recent.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) => _JournalPolaroid(memory: recent[i]),
      ),
    );
  }
}

class _JournalPolaroid extends StatelessWidget {
  const _JournalPolaroid({required this.memory});

  final MemoryModel memory;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${memory.title}, ${AppFormatters.dayMonthYear(memory.memoryDate)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MemoryDetailScreen(memory: memory)),
        ),
        child: SizedBox(
          width: 128,
          child: PolaroidFrame(
            seed: memory.id,
            caption: memory.title,
            ornament: memory.id.isEven,
            photo: MemoryCover(memory: memory),
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;

    Widget action(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(t.buttonRadius),
                    border: Border.all(color: t.border),
                    boxShadow: t.elevation(1),
                  ),
                  child: Icon(icon, color: t.primary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: t.label.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        action(
          Icons.add_a_photo_outlined,
          'New memory',
          () => context.push('/memories/create'),
        ),
        action(
          Icons.edit_calendar_outlined,
          'Plan a date',
          () => Navigator.of(
            context,
            rootNavigator: true,
          ).push(MaterialPageRoute(builder: (_) => const DateFormScreen())),
        ),
        action(
          Icons.photo_camera_back_outlined,
          'Photo Booth',
          () => openPhotoBooth(context, ref),
        ),
        action(
          Icons.palette_outlined,
          'Themes',
          () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ThemeGalleryScreen())),
        ),
      ],
    );
  }
}

/// Latest things either of you did, built from data already loaded for the
/// other sections (no extra request). Comments are not included: they would
/// need one request per memory.
class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.dates,
    required this.memories,
    required this.couple,
    required this.me,
  });

  final List<DateModel> dates;
  final List<MemoryModel> memories;
  final CoupleModel couple;
  final UserModel? me;

  String _who(int? userId) {
    if (userId == null) return 'Someone';
    if (userId == me?.id) return 'You';
    return couple.members
            .where((m) => m.id == userId)
            .firstOrNull
            ?.name
            .split(' ')
            .first ??
        'Your partner';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final items = <(DateTime, String, String, IconData)>[
      for (final d in dates)
        if (d.createdAt != null)
          (
            d.createdAt!,
            _who(d.createdBy),
            'planned ${d.title}',
            Icons.event_outlined,
          ),
      for (final d in dates)
        if (d.completedAt != null)
          (
            d.completedAt!,
            'You both',
            'went on ${d.title}',
            Icons.favorite_border_rounded,
          ),
      for (final m in memories)
        if (m.createdAt != null)
          (
            m.createdAt!,
            _who(m.createdBy),
            (m.photosCount ?? 0) > 0
                ? 'saved ${m.title} with ${m.photosCount} photo${m.photosCount == 1 ? '' : 's'}'
                : 'saved ${m.title}',
            Icons.photo_library_outlined,
          ),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Recently'),
        const SizedBox(height: AppSpacing.sm),
        for (final (at, who, what, icon) in items.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: t.textSecondary),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: who,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: ' $what'),
                      ],
                    ),
                    style: t.body.copyWith(fontSize: 14),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(AppFormatters.sinceShort(at), style: t.caption),
              ],
            ),
          ),
      ],
    );
  }
}

class _Onboarding extends ConsumerWidget {
  const _Onboarding({required this.onJoined});

  final Future<void> Function() onJoined;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final isLoading =
        ref.watch(coupleNotifierProvider.select((s) => s.status)) ==
        CoupleStatus.loading;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - AppSpacing.xl * 2,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SpotIllustration(kind: SpotKind.heart, size: 128),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'A little space for two',
                style: t.display.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Plan dates, keep your memories and photos together. '
                'Everything is private to the two of you.',
                style: t.body.copyWith(color: t.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Create our space',
                isLoading: isLoading,
                onPressed: () =>
                    ref.read(coupleNotifierProvider.notifier).createCouple(),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'I have an invitation',
                variant: AppButtonVariant.secondary,
                onPressed: isLoading
                    ? null
                    : () async {
                        final accepted = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => const AcceptInvitationScreen(),
                          ),
                        );
                        if (accepted == true) await onJoined();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
