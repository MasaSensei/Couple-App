import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/date_providers.dart';
import '../providers/date_state.dart';
import 'date_form_screen.dart';
import 'date_detail_screen.dart';

class DateListScreen extends ConsumerStatefulWidget {
  const DateListScreen({super.key});

  @override
  ConsumerState<DateListScreen> createState() => _DateListScreenState();
}

class _DateListScreenState extends ConsumerState<DateListScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() => ref.read(dateNotifierProvider.notifier).loadDates());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dateNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Our Dates')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const DateFormScreen()));
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Plan a date'),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(DateState state) {
    switch (state.status) {
      case DateStatus.initial:
      case DateStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case DateStatus.empty:
        return _buildEmpty();

      case DateStatus.error:
        return _buildError(state.errorMessage ?? 'Unable to load dates.');

      case DateStatus.loaded:
        return _buildList(state);
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_border_rounded, size: 64),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No dates yet ♡',
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your little plans together '
              'will appear here.',
              style: AppTextStyles.subtitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          message,
          style: AppTextStyles.subtitle,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildList(DateState state) {
    return RefreshIndicator(
      onRefresh: () {
        return ref.read(dateNotifierProvider.notifier).loadDates();
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: state.dates.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final date = state.dates[index];

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DateDetailScreen(dateId: date.id),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date.title, style: AppTextStyles.title),

                    const SizedBox(height: AppSpacing.sm),

                    Text(
                      _formatDate(date.scheduledAt),
                      style: AppTextStyles.subtitle,
                    ),

                    if (date.location != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(date.location!, style: AppTextStyles.body),
                    ],

                    const SizedBox(height: AppSpacing.md),

                    _buildStatus(date.status),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatus(String status) {
    return Text(status.toUpperCase(), style: AppTextStyles.body);
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();

    final day = localDate.day.toString().padLeft(2, '0');

    final month = localDate.month.toString().padLeft(2, '0');

    final year = localDate.year;

    final hour = localDate.hour.toString().padLeft(2, '0');

    final minute = localDate.minute.toString().padLeft(2, '0');

    return '$day/$month/$year • $hour:$minute';
  }
}
