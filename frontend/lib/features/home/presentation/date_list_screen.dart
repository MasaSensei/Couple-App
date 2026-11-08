import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart';
import '../data/models/date_model.dart';
import '../providers/date_providers.dart';
import '../providers/date_state.dart';
import 'date_detail_screen.dart';
import 'date_form_screen.dart';
import 'widgets/date_status_chip.dart';

/// Date planner: a week strip to glance at, upcoming plans as ticket cards,
/// and past dates grouped by month.
class DateListScreen extends ConsumerStatefulWidget {
  const DateListScreen({super.key});

  @override
  ConsumerState<DateListScreen> createState() => _DateListScreenState();
}

class _DateListScreenState extends ConsumerState<DateListScreen> {
  bool _showPast = false;
  late DateTime _weekStart = _mondayOf(DateTime.now());
  DateTime? _selectedDay;

  static DateTime _mondayOf(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return local.subtract(Duration(days: local.weekday - 1));
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(dateNotifierProvider.notifier).loadDates());
  }

  Future<void> _refresh() =>
      ref.read(dateNotifierProvider.notifier).loadDates();

  Future<void> _planDate() => Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute(builder: (_) => const DateFormScreen()));

  void _open(DateModel date) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => DateDetailScreen(dateId: date.id)));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dateNotifierProvider);

    return AppScaffold(
      title: 'Our dates',
      padded: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _planDate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Plan a date'),
      ),
      body: switch (state.status) {
        DateStatus.initial || DateStatus.loading when state.dates.isEmpty =>
          const AppStateView.loading(),
        DateStatus.error when state.dates.isEmpty => RefreshIndicator(
          onRefresh: _refresh,
          child: AppStateView.error(
            message: state.errorMessage ?? 'We could not load your dates.',
            onAction: _refresh,
            scrollable: true,
          ),
        ),
        DateStatus.empty => RefreshIndicator(
          onRefresh: _refresh,
          child: AppStateView.empty(
            title: 'No dates yet',
            message: 'Plan your first little adventure together.',
            actionLabel: 'Plan a date',
            onAction: _planDate,
            illustration: SpotKind.calendar,
            scrollable: true,
          ),
        ),
        _ => RefreshIndicator(
          onRefresh: _refresh,
          child: _buildList(state.dates),
        ),
      },
    );
  }

  Widget _buildList(List<DateModel> all) {
    final t = context.tokens;
    final now = DateTime.now();

    final upcoming =
        all.where((d) => DateStatusStyle.isUpcoming(d, now: now)).toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final past =
        all.where((d) => !DateStatusStyle.isUpcoming(d, now: now)).toList()
          ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    var shown = _showPast ? past : upcoming;
    if (_selectedDay != null) {
      shown =
          all
              .where(
                (d) =>
                    AppFormatters.daysBetween(_selectedDay!, d.scheduledAt) ==
                    0,
              )
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    }

    final items = <Widget>[
      _WeekStrip(
        weekStart: _weekStart,
        selected: _selectedDay,
        dates: all,
        onPrevious: () => setState(
          () => _weekStart = _weekStart.subtract(const Duration(days: 7)),
        ),
        onNext: () => setState(
          () => _weekStart = _weekStart.add(const Duration(days: 7)),
        ),
        onSelect: (day) => setState(() {
          _selectedDay =
              _selectedDay != null &&
                  AppFormatters.daysBetween(_selectedDay!, day) == 0
              ? null
              : day;
        }),
      ),
      const SizedBox(height: AppSpacing.md),
      if (_selectedDay != null)
        Row(
          children: [
            Expanded(
              child: Text(
                AppFormatters.full(_selectedDay!).split(' · ').first,
                style: t.heading,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedDay = null),
              child: const Text('Show all'),
            ),
          ],
        )
      else
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: false,
              label: Text('Upcoming · ${upcoming.length}'),
            ),
            ButtonSegment(value: true, label: Text('Past · ${past.length}')),
          ],
          selected: {_showPast},
          onSelectionChanged: (s) => setState(() => _showPast = s.first),
        ),
      const SizedBox(height: AppSpacing.md),
    ];

    if (shown.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Text(
            _selectedDay != null
                ? 'Nothing on this day.'
                : _showPast
                ? 'Past dates will gather here.'
                : 'Nothing planned yet. Tap "Plan a date" to add one.',
            style: t.body.copyWith(color: t.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      String? lastMonth;
      for (final date in shown) {
        final month = AppFormatters.monthYear(date.scheduledAt);
        if (_showPast && _selectedDay == null && month != lastMonth) {
          items.add(
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
              child: SectionHeader(title: month),
            ),
          );
          lastMonth = month;
        }
        items.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.smd),
            child: DateTicketCard(
              date: date,
              now: now,
              onTap: () => _open(date),
            ),
          ),
        );
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        96, // room for the FAB
      ),
      children: items,
    );
  }
}

/// Ticket-style card for one date. Shared by the planner and Home.
class DateTicketCard extends StatelessWidget {
  const DateTicketCard({
    required this.date,
    required this.onTap,
    super.key,
    this.now,
  });

  final DateModel date;
  final VoidCallback onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final upcoming = DateStatusStyle.isUpcoming(date, now: now);
    final emphasis = switch (date.status) {
      'cancelled' => DateBadgeEmphasis.muted,
      'completed' => DateBadgeEmphasis.soft,
      _ => upcoming ? DateBadgeEmphasis.strong : DateBadgeEmphasis.soft,
    };
    final (statusLabel, _, _) = DateStatusStyle.of(date.status);
    final meta = [
      AppFormatters.weekdayTime(date.scheduledAt),
      ?date.location,
    ].join(' · ');

    return JournalCard(
      ornament: upcoming,
      ornamentSeed: date.id,
      onTap: onTap,
      semanticLabel:
          '${date.title}, ${AppFormatters.full(date.scheduledAt)}'
          '${date.location == null ? '' : ', ${date.location}'}, $statusLabel',
      child: Row(
        children: [
          DateBadge(date: date.scheduledAt, emphasis: emphasis),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date.title,
                  style: t.heading.copyWith(
                    decoration: date.status == 'cancelled'
                        ? TextDecoration.lineThrough
                        : null,
                    color: date.status == 'cancelled' ? t.textSecondary : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: t.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    DateStatusChip(status: date.status),
                    if (upcoming)
                      StatusChip(
                        label: AppFormatters.relativeDays(
                          date.scheduledAt,
                          now: now,
                        ),
                        tone: StatusTone.neutral,
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: t.textSecondary),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.weekStart,
    required this.selected,
    required this.dates,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });

  final DateTime weekStart;
  final DateTime? selected;
  final List<DateModel> dates;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final today = DateTime.now();
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return JournalCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous week',
              ),
              Expanded(
                child: Text(
                  AppFormatters.monthYear(days[3]),
                  style: t.heading.copyWith(fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next week',
              ),
            ],
          ),
          Row(
            children: [
              for (final day in days)
                Expanded(child: _day(context, day, today)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _day(BuildContext context, DateTime day, DateTime today) {
    final t = context.tokens;
    final isToday = AppFormatters.daysBetween(today, day) == 0;
    final isSelected =
        selected != null && AppFormatters.daysBetween(selected!, day) == 0;
    final count = dates
        .where((d) => AppFormatters.daysBetween(day, d.scheduledAt) == 0)
        .length;

    final Color bg = isSelected
        ? t.primary
        : isToday
        ? t.secondary
        : Colors.transparent;
    final Color fg = isSelected ? t.onPrimary : t.textPrimary;

    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${AppFormatters.dayMonthYear(day)}${isToday ? ', today' : ''}'
          '${count == 0 ? '' : ', $count date${count == 1 ? '' : 's'}'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onSelect(day),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppFormatters.weekdayShort(day).substring(0, 1),
                style: t.caption.copyWith(
                  color: isSelected ? t.onPrimary : t.textSecondary,
                ),
              ),
              Text(
                '${day.day}',
                style: t.heading.copyWith(fontSize: 15, color: fg),
              ),
              const SizedBox(height: 2),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: count == 0
                      ? Colors.transparent
                      : (isSelected ? t.onPrimary : t.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
