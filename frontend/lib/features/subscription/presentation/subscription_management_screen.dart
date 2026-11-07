import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_spacing.dart';

import '../data/subscription_models.dart';
import '../providers/subscription_controller.dart';
import 'billing_format.dart';
import 'subscription_overview_screen.dart' show renewalLine;

/// Status, renewal, cancel, restore and history. The cancel button is a
/// normal, visible button with a plain confirmation — no retention tricks.
class SubscriptionManagementScreen extends ConsumerStatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  ConsumerState<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends ConsumerState<SubscriptionManagementScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(subscriptionControllerProvider.notifier).loadTransactions());
  }

  void _show(BillingOutcome outcome) {
    if (!mounted) return;
    final message = switch (outcome) {
      BillingSucceeded(:final message) => message,
      BillingDismissed() => 'Nothing changed.',
      BillingFailed(:final message, :final managementUrl) => managementUrl == null ? message : '$message\n$managementUrl',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 6)));
  }

  Future<void> _cancel(CoupleSubscription subscription) async {
    final end = subscription.currentPeriodEnd;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel auto-renew?'),
        content: Text(
          'You will not be charged again. '
          '${end == null ? '' : 'Your benefits continue until ${BillingFormat.date(end)}. '}'
          'After that you both move to Free. Your photos and memories are not deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep subscription')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel auto-renew')),
        ],
      ),
    );
    if (confirmed != true) return;
    _show(await ref.read(subscriptionControllerProvider.notifier).cancelRenewal());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionControllerProvider);
    final controller = ref.read(subscriptionControllerProvider.notifier);
    final subscription = state.overview?.subscription;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage subscription')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: subscription == null
                  ? const Text('You are on the Free plan. There is nothing to renew or cancel.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subscription.planName, style: text.titleLarge),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Status: ${BillingFormat.status(subscription.status)}'),
                        Text(BillingFormat.priceWithInterval(
                          subscription.priceAmount,
                          subscription.currency,
                          subscription.billingInterval,
                          subscription.billingIntervalCount,
                        )),
                        const SizedBox(height: AppSpacing.sm),
                        Text(renewalLine(subscription)),
                        const SizedBox(height: AppSpacing.md),
                        if (subscription.canManage && subscription.autoRenew && subscription.status != 'expired')
                          OutlinedButton(
                            onPressed: state.busy ? null : () => _cancel(subscription),
                            child: const Text('Cancel auto-renew'),
                          )
                        else if (!subscription.canManage && subscription.startedBy == 'partner')
                          Text(
                            'Your partner manages billing for this subscription because it is charged to their store account. '
                            'Only they can cancel or change it.',
                            style: text.bodySmall,
                          ),
                        if (subscription.managementUrl != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text('You can also manage it in the store:', style: text.bodySmall),
                          SelectableText(subscription.managementUrl!, style: text.bodySmall),
                          TextButton.icon(
                            onPressed: () => Clipboard.setData(ClipboardData(text: subscription.managementUrl!)),
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Copy link'),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: state.busy ? null : () async => _show(await controller.restore()),
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Restore purchases'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Billing history', style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          switch (state.transactions) {
            null => const Center(child: CircularProgressIndicator()),
            final List<BillingTransaction> list when list.isEmpty => const Text('No payments yet.'),
            final List<BillingTransaction> list => Column(
                children: [
                  for (final t in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${_typeLabel(t.type)}${t.planName == null ? '' : ' · ${t.planName}'}${t.isTest ? ' (test)' : ''}'),
                      subtitle: Text(BillingFormat.date(t.occurredAt)),
                      trailing: Text(BillingFormat.price(t.amount, t.currency)),
                    ),
                ],
              ),
          },
        ],
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
        'purchase' => 'Purchase',
        'renewal' => 'Renewal',
        'refund' => 'Refund',
        'chargeback' => 'Payment reversed',
        _ => 'Adjustment',
      };
}
