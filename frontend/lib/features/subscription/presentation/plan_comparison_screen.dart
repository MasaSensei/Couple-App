import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/app_widgets.dart';

import '../data/purchase_gateway.dart';
import '../data/subscription_models.dart';
import '../providers/subscription_controller.dart';
import 'billing_format.dart';
import 'subscription_widgets.dart';

/// Side-by-side plans with full price, interval and renewal terms.
class PlanComparisonScreen extends ConsumerStatefulWidget {
  const PlanComparisonScreen({super.key});

  @override
  ConsumerState<PlanComparisonScreen> createState() =>
      _PlanComparisonScreenState();
}

class _PlanComparisonScreenState extends ConsumerState<PlanComparisonScreen> {
  @override
  void initState() {
    super.initState();
    if (ref.read(subscriptionControllerProvider).plans.isEmpty) {
      Future.microtask(
        () => ref.read(subscriptionControllerProvider.notifier).load(),
      );
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue to payment'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final outcome = await ref
        .read(subscriptionControllerProvider.notifier)
        .purchase(plan);
    if (!mounted) return;

    final message = switch (outcome) {
      BillingSucceeded(:final message) => message,
      BillingDismissed() => 'Purchase cancelled. You were not charged.',
      BillingFailed(:final message) => message,
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
          ? (state.loading
                ? const AppStateView.loading()
                : AppStateView.error(
                    title: 'Plans are not available',
                    message: state.error ?? 'No plans available.',
                    onAction: () => ref
                        .read(subscriptionControllerProvider.notifier)
                        .load(),
                  ))
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.xxl,
              ),
              children: [
                Text(
                  'One subscription covers both of you. Prices include everything; there are no hidden fees.',
                  style: context.tokens.body.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!canPurchase)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: NoticeBanner(
                      tone: StatusTone.warning,
                      message: UnavailablePurchaseGateway.message,
                    ),
                  ),
                for (final plan in state.plans)
                  _PlanCard(
                    plan: plan,
                    action: plan.isCurrent || plan.isFree
                        ? null
                        : (canPurchase && !state.busy
                              ? () => _choose(plan)
                              : null),
                    actionLabel: hasSubscription
                        ? 'Switch to ${plan.name}'
                        : 'Choose ${plan.name}',
                  ),
                const SizedBox(height: AppSpacing.md),
                const AlwaysIncludedNote(),
              ],
            ),
    );
  }
}

String renewalTerms(SubscriptionPlan plan) {
  final period = BillingFormat.interval(
    plan.billingInterval,
    plan.billingIntervalCount,
  ).replaceFirst('per ', 'every ');
  return 'Renews automatically $period at the same price until you cancel. '
      'You can cancel anytime in Manage subscription; benefits continue until the end of the period you paid for.';
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.action,
    required this.actionLabel,
  });

  final SubscriptionPlan plan;
  final VoidCallback? action;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.cardRadius + 2),
          border: plan.isCurrent
              ? Border.all(color: t.primary, width: 2)
              : null,
        ),
        child: JournalCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(plan.name, style: t.title)),
                  if (plan.isCurrent)
                    const StatusChip(
                      label: 'Current',
                      tone: StatusTone.brand,
                      icon: Icons.check_rounded,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                BillingFormat.priceWithInterval(
                  plan.priceAmount,
                  plan.currency,
                  plan.billingInterval,
                  plan.billingIntervalCount,
                ),
                style: t.heading.copyWith(color: t.primary),
              ),
              if (plan.description != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(plan.description!, style: t.body),
              ],
              const SizedBox(height: AppSpacing.smd),
              for (final feature in plan.features) FeatureRow(feature: feature),
              if (plan.autoRenews) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(renewalTerms(plan), style: t.caption),
              ],
              if (!plan.isFree && !plan.isCurrent) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: action,
                    child: Text(actionLabel),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
