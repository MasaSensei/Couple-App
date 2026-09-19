import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/models/date_model.dart';
import '../providers/date_providers.dart';
import 'date_form_screen.dart';
import 'date_comments_section.dart';

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
      title: 'Complete this date?',
      message: 'This will mark "${date.title}" as completed.',
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

      _showMessage('Date marked as completed ♡');
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
      message: 'This will cancel "${date.title}".',
      confirmLabel: 'Cancel date',
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
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Date Details')),
      body: FutureBuilder<DateModel>(
        future: _dateFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildError();
          }

          final date = snapshot.data;

          if (date == null) {
            return _buildError();
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date.title, style: AppTextStyles.title),

                  const SizedBox(height: AppSpacing.sm),

                  _buildStatus(date.status),

                  const SizedBox(height: AppSpacing.xl),

                  _buildInfoCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'Date & Time',
                    value: _formatDateTime(date.scheduledAt),
                  ),

                  if (date.location != null &&
                      date.location!.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildInfoCard(
                      icon: Icons.location_on_rounded,
                      title: 'Location',
                      value: date.location!,
                    ),
                  ],

                  if (date.description != null &&
                      date.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildDescriptionCard(date.description!),
                  ],

                  const SizedBox(height: AppSpacing.xl),

                  DateCommentsSection(dateId: date.id),

                  const SizedBox(height: AppSpacing.xl),

                  _buildStatusActions(date),

                  const SizedBox(height: AppSpacing.xl),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _editDate(date);
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit date'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatus(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(status.toUpperCase(), style: AppTextStyles.body),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.subtitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(value, style: AppTextStyles.body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard(String description) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Description', style: AppTextStyles.subtitle),
            const SizedBox(height: AppSpacing.sm),
            Text(description, style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Unable to load this date.',
              style: AppTextStyles.subtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: _refresh, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusActions(DateModel date) {
    if (_isUpdatingStatus) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (date.status) {
      case 'planned':
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  _completeDate(date);
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Mark as completed'),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _cancelDate(date);
                },
                icon: const Icon(Icons.close_rounded),
                label: const Text('Cancel date'),
              ),
            ),
          ],
        );

      case 'completed':
        return const Text(
          'This date has been completed ♡',
          textAlign: TextAlign.center,
        );

      case 'cancelled':
        return const Text(
          'This date was cancelled.',
          textAlign: TextAlign.center,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDateTime(DateTime date) {
    final localDate = date.toLocal();

    final day = localDate.day.toString().padLeft(2, '0');

    final month = localDate.month.toString().padLeft(2, '0');

    final year = localDate.year;

    final hour = localDate.hour.toString().padLeft(2, '0');

    final minute = localDate.minute.toString().padLeft(2, '0');

    return '$day/$month/$year • $hour:$minute';
  }
}
