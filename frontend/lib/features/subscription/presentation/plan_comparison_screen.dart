import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_spacing.dart';

import '../data/purchase_gateway.dart';
import '../data/subscription_models.dart';
import '../providers/subscription_controller.dart';
import 'billing_format.dart';
import 'subscription_widgets.dart';

/// Side-by-side plans with full price, interval and renewal terms.
class PlanComparisonScreen extends ConsumerStatefulWidget {
  const PlanComparisonScreen({super.key});

  @override
  ConsumerState<PlanComparisonScreen> createState() => _PlanComparisonScreenState();
}

class _PlanComparisonScreenState extends ConsumerState<PlanComparisonScreen> {
  @override
  void initState() {
    super.initState();
    if (ref.read(subscriptionControllerProvider).plans.isEmpty) {
      Future.microtask(() => ref.read(subscriptionControllerProvider.notifier).load());
    }
  }

  Future<void> _choose(SubscriptionPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Subscribe to ${plan.name}?'),
        content: Text(
          '${BillingFormat.priceWithInterval(plan.priceAmount, plan.currency, plan.billingInterval, plan.billingIntervalCount)}, '
          'charged to your store account.\n\n'
          '${renewalTerms(plan)}\n\n'
          'Your partner gets the same benefits at no extra cost.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue to payment')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final outcome = await ref.read(subscriptionControllerProvider.notifier).purchase(plan);
    if (!mounted) return;

    final message = switch (outcome) {
      BillingSucceeded(:final message) => message,
      BillingDismissed() => 'Purchase cancelled. You were not charged.',
      BillingFailed(:final message) => message,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    if (outcome is BillingSucceeded) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionControllerProvider);
    final controller = ref.read(subscriptionControllerProvider.notifier);
    final canPurchase = controller.canPurchase;
    final hasSubscription = state.overview?.subscription != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Compare plans')),
      body: state.plans.isEmpty
          ? Center(child: state.loading ? const CircularProgressIndicator() : Text(state.error ?? 'No plans available.'))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (!canPurchase)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(UnavailablePurchaseGateway.message),
                  ),
                for (final plan in state.plans)
                  _PlanCard(
                    plan: plan,
                    action: plan.isCurrent || plan.isFree
                        ? null
                        : (canPurchase && !state.busy ? () => _choose(plan) : null),
                    actionLabel: hasSubscription ? 'Switch to ${plan.name}' : 'Choose ${plan.name}',
                  ),
                const SizedBox(height: AppSpacing.md),
                const AlwaysIncludedNote(),
              ],
            ),
    );
  }
}

String renewalTerms(SubscriptionPlan plan) {
  final period = BillingFormat.interval(plan.billingInterval, plan.billingIntervalCount).replaceFirst('per ', 'every ');
  return 'Renews automatically $period at the same price until you cancel. '
      'You can cancel anytime in Manage subscription; benefits continue until the end of the period you paid for.';
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.action, required this.actionLabel});

  final SubscriptionPlan plan;
  final VoidCallback? action;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      shape: plan.isCurrent
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: scheme.primary, width: 2))
          : null,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(plan.name, style: text.titleLarge)),
              if (plan.isCurrent) Chip(label: const Text('Current')),
            ]),
            Text(
              BillingFormat.priceWithInterval(plan.priceAmount, plan.currency, plan.billingInterval, plan.billingIntervalCount),
              style: text.titleMedium?.copyWith(color: scheme.primary),
            ),
            if (plan.description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(plan.description!),
            ],
            const SizedBox(height: AppSpacing.sm),
            for (final feature in plan.features) FeatureRow(feature: feature),
            if (plan.autoRenews) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(renewalTerms(plan), style: text.bodySmall),
            ],
            if (!plan.isFree && !plan.isCurrent) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: action, child: Text(actionLabel)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
