import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/theme/app_spacing.dart';

import '../data/subscription_models.dart';
import '../providers/subscription_controller.dart';
import 'billing_format.dart';
import 'plan_comparison_screen.dart';
import 'storage_screen.dart';
import 'subscription_management_screen.dart';
import 'subscription_widgets.dart';

/// "Plan & storage": current plan, status, renewal, storage, benefits.
class SubscriptionOverviewScreen extends ConsumerStatefulWidget {
  const SubscriptionOverviewScreen({super.key});

  @override
  ConsumerState<SubscriptionOverviewScreen> createState() =>
      _SubscriptionOverviewScreenState();
}

class _SubscriptionOverviewScreenState
    extends ConsumerState<SubscriptionOverviewScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(subscriptionControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionControllerProvider);
    final overview = state.overview;

    return Scaffold(
      appBar: AppBar(title: const Text('Plan & storage')),
      body: switch ((overview, state.loading, state.error)) {
        (null, true, _) => const Center(child: CircularProgressIndicator()),
        (null, _, final String error) => _Error(message: error),
        (null, _, _) => const Center(child: CircularProgressIndicator()),
        (final SubscriptionOverview overview, _, _) => RefreshIndicator(
          onRefresh: () =>
              ref.read(subscriptionControllerProvider.notifier).load(),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _CurrentPlanCard(overview: overview, plan: state.currentPlan),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StorageScreen()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Photo storage',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        StorageUsageBar(storage: overview.storage),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (state.currentPlan != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your benefits',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final feature in state.currentPlan!.features)
                          FeatureRow(feature: feature),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PlanComparisonScreen(),
                  ),
                ),
                icon: const Icon(Icons.compare_arrows_rounded),
                label: const Text('Compare plans'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionManagementScreen(),
                  ),
                ),
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Manage subscription'),
              ),
              const SizedBox(height: AppSpacing.lg),
              const AlwaysIncludedNote(),
            ],
          ),
        ),
      },
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.overview, required this.plan});

  final SubscriptionOverview overview;
  final SubscriptionPlan? plan;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subscription = overview.subscription;
    final name = subscription?.planName ?? plan?.name ?? 'Free';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current plan', style: text.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(name, style: text.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            if (subscription == null)
              const Text('Free — no payment, no renewal.')
            else ...[
              Chip(label: Text(BillingFormat.status(subscription.status))),
              Text(
                BillingFormat.priceWithInterval(
                  subscription.priceAmount,
                  subscription.currency,
                  subscription.billingInterval,
                  subscription.billingIntervalCount,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(renewalLine(subscription)),
              const SizedBox(height: AppSpacing.xs),
              Text(switch (subscription.startedBy) {
                'me' => 'You started this subscription; it is billed to your store account.',
                'support' =>
                  'Granted by support. It does not renew or charge anyone.',
                _ => 'Started by your partner. You both get every benefit.',
              }, style: text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// One sentence that always says what happens next with money and benefits.
String renewalLine(CoupleSubscription s) {
  String on(DateTime? d) => d == null ? '' : ' on ${BillingFormat.date(d)}';

  return switch (s.status) {
    'active' when s.autoRenew =>
      'Renews automatically${on(s.renewsAt)}. You can cancel anytime.',
    'active' => 'Benefits end${on(s.benefitsEndAt)}. It will not renew.',
    'cancelled' =>
      s.benefitsEndAt == null
          ? 'Auto-renew is off. Benefits continue until the paid period ends, then you move to Free. Nothing is deleted.'
          : 'Auto-renew is off. Benefits continue until ${BillingFormat.date(s.benefitsEndAt!)}, then you move to Free. Nothing is deleted.',
    'grace_period' =>
      'The store could not take the last payment. Update your payment method in the store${s.graceEndsAt == null ? '' : ' before ${BillingFormat.date(s.graceEndsAt!)}'}.',
    'payment_failed' => 'Payment failed. Paid benefits are paused until the payment method is fixed in the store. Your photos are safe.',
    'suspended' => 'Paused. Your photos and memories are untouched.',
    'pending' => 'Waiting for the store to confirm the payment.',
    _ => 'This subscription has ended.',
  };
}

class _Error extends StatelessWidget {
  const _Error({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
