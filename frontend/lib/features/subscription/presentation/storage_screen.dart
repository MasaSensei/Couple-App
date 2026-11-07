import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_spacing.dart';

import '../data/subscription_models.dart';
import '../providers/subscription_controller.dart';
import 'billing_format.dart';
import 'plan_comparison_screen.dart';
import 'subscription_widgets.dart';

class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(subscriptionControllerProvider).overview?.storage;

    return Scaffold(
      appBar: AppBar(title: const Text('Photo storage')),
      body: storage == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(subscriptionControllerProvider.notifier).load(),
              child: StorageDetails(storage: storage),
            ),
    );
  }
}

class StorageDetails extends StatelessWidget {
  const StorageDetails({super.key, required this.storage});

  final StorageUsage storage;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        StorageUsageBar(storage: storage),
        const SizedBox(height: AppSpacing.lg),
        _Row(label: 'Photos (${storage.photoCount})', value: BillingFormat.bytes(storage.usedBytes)),
        if (storage.reservedBytes > 0) _Row(label: 'Uploads in progress', value: BillingFormat.bytes(storage.reservedBytes)),
        if (storage.trashBytes > 0) _Row(label: 'Recently deleted (not counted)', value: BillingFormat.bytes(storage.trashBytes)),
        _Row(label: 'Your plan’s storage', value: BillingFormat.bytes(storage.limitBytes)),
        _Row(label: 'Remaining', value: BillingFormat.bytes(storage.remainingBytes)),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Counted: the encrypted size of each photo, once. Our backup copy is never counted against you, '
          'and recently deleted photos don’t count (restoring one needs free space again).',
          style: text.bodySmall,
        ),
        if (storage.isFull) ...[
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your storage is full', style: text.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  if (storage.isOverLimit)
                    const Text('You are above your plan’s storage, for example because a paid plan ended. Nothing was deleted.'),
                  const Text(
                    'You can still open, download and delete every photo and use all your memories. '
                    'Only new photos can’t be added until there is space: delete some photos, or choose a plan with more storage.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlanComparisonScreen())),
                    child: const Text('See plans'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))]),
      );
}
