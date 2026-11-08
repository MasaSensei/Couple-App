import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/memories/data/models/memory_form_data.dart';

import '../../../core/widgets/app_widgets.dart';
import 'widgets/date_status_chip.dart';
import '../data/models/date_model.dart';
import '../providers/date_providers.dart';
import 'date_form_screen.dart';
import 'date_comments_section.dart';
import '../../memories/presentation/screens/memory_form_screen.dart';
import '../../memories/data/models/memory_model.dart';
import '../../memories/presentation/screens/memory_detail_screen.dart';

class DateDetailScreen extends ConsumerStatefulWidget {
  const DateDetailScreen({super.key, required this.dateId});

  final int dateId;

  @override
  ConsumerState<DateDetailScreen> createState() => _DateDetailScreenState();
}

class _DateDetailScreenState extends ConsumerState<DateDetailScreen> {
  late Future<DateModel> _dateFuture;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();

    _dateFuture = _loadDate();
  }

  Future<DateModel> _loadDate() {
    final repository = ref.read(dateRepositoryProvider);

    return repository.getDateById(widget.dateId);
  }

  Future<void> _refresh() async {
    setState(() {
      _dateFuture = _loadDate();
    });

    await _dateFuture;
  }

  Future<void> _editDate(DateModel date) async {
    final result = await Navigator.of(context).push<DateModel>(
      MaterialPageRoute(builder: (_) => DateFormScreen(date: date)),
    );

    if (!mounted || result == null) {
      return;
    }

    await _refresh();
  }

  Future<void> _completeDate(DateModel date) async {
    final confirmed = await _showConfirmation(
      title: 'Mark as completed?',
      message: 'You can then save "${date.title}" as a memory with photos.',
      confirmLabel: 'Complete',
    );

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _isUpdatingStatus = true;
    });

    final updatedDate = await ref
        .read(dateNotifierProvider.notifier)
        .completeDate(date.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _isUpdatingStatus = false;
    });

    if (updatedDate != null) {
      setState(() {
        _dateFuture = Future.value(updatedDate);
      });

      _showMessage('Marked as completed.');
      return;
    }

    _showMessage(
      ref.read(dateNotifierProvider).errorMessage ??
          'Unable to complete this date.',
    );
  }

  Future<void> _cancelDate(DateModel date) async {
    final confirmed = await _showConfirmation(
      title: 'Cancel this date?',
      message: '"${date.title}" will move to your past dates as cancelled.',
      confirmLabel: 'Cancel date',
      destructive: true,
    );

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _isUpdatingStatus = true;
    });

    final updatedDate = await ref
        .read(dateNotifierProvider.notifier)
        .cancelDate(date.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _isUpdatingStatus = false;
    });

    if (updatedDate != null) {
      setState(() {
        _dateFuture = Future.value(updatedDate);
      });

      _showMessage('Date cancelled.');
      return;
    }

    _showMessage(
      ref.read(dateNotifierProvider).errorMessage ??
          'Unable to cancel this date.',
    );
  }

  Future<bool> _showConfirmation({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showConfirmSheet(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: 'Not now',
      destructive: destructive,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Date',
      padded: false,
      body: FutureBuilder<DateModel>(
        future: _dateFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppStateView.loading();
          }

          final date = snapshot.data;
          if (snapshot.hasError || date == null) {
            return AppStateView.error(
              message: 'We could not load this date.',
              onAction: _refresh,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.xxl,
              ),
              children: [
                _buildHero(date),
                const SizedBox(height: AppSpacing.lg),
                _buildStatusActions(date),
                if (date.description != null &&
                    date.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(title: 'Notes'),
                  const SizedBox(height: AppSpacing.sm),
                  Text(date.description!, style: context.tokens.body),
                ],
                const SizedBox(height: AppSpacing.xl),
                DateCommentsSection(dateId: date.id),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Edit date',
                  icon: Icons.edit_outlined,
                  variant: AppButtonVariant.ghost,
                  onPressed: () => _editDate(date),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHero(DateModel date) {
    final t = context.tokens;
    final upcoming = DateStatusStyle.isUpcoming(date);

    Widget info(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: t.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: t.body)),
        ],
      ),
    );

    return JournalCard(
      ornament: true,
      ornamentSeed: date.id,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DateBadge(
                date: date.scheduledAt,
                width: 64,
                emphasis: date.status == 'cancelled'
                    ? DateBadgeEmphasis.muted
                    : upcoming
                    ? DateBadgeEmphasis.strong
                    : DateBadgeEmphasis.soft,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(date.title, style: t.title),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        DateStatusChip(status: date.status, dense: false),
                        if (upcoming)
                          StatusChip(
                            label: AppFormatters.relativeDays(date.scheduledAt),
                            tone: StatusTone.neutral,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          info(Icons.schedule_rounded, AppFormatters.full(date.scheduledAt)),
          if (date.location != null && date.location!.trim().isNotEmpty)
            info(Icons.place_outlined, date.location!),
        ],
      ),
    );
  }

  Widget _buildStatusActions(DateModel date) {
    final t = context.tokens;
    if (_isUpdatingStatus) return const AppStateView.loading();

    switch (date.status) {
      case 'planned':
        return Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Completed',
                icon: Icons.check_rounded,
                onPressed: () => _completeDate(date),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton(
                label: 'Cancel date',
                icon: Icons.close_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: () => _cancelDate(date),
              ),
            ),
          ],
        );

      case 'completed':
        return JournalCard(
          color: t.toneContainer(StatusTone.success),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'You went on this date. Keep it in your journal?',
                style: t.body.copyWith(
                  color: t.onToneContainer(StatusTone.success),
                ),
              ),
              const SizedBox(height: AppSpacing.smd),
              AppButton(
                label: 'Save this moment',
                icon: Icons.favorite_border_rounded,
                onPressed: () => _createMemoryFromDate(date),
              ),
            ],
          ),
        );

      case 'cancelled':
        return Text(
          'This date was cancelled.',
          style: t.body.copyWith(color: t.textSecondary),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _createMemoryFromDate(DateModel date) async {
    final result = await Navigator.of(context).push<MemoryModel>(
      MaterialPageRoute(
        builder: (_) => MemoryFormScreen(
          initialData: MemoryFormData(
            title: date.title,
            description: date.description,
            memoryDate: date.scheduledAt,
            locationName: date.location,
            dateId: date.id,
          ),
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MemoryDetailScreen(memory: result)),
    );
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
  }
}
