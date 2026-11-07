import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/subscription/data/purchase_gateway.dart';
import 'package:frontend/features/subscription/data/subscription_models.dart';
import 'package:frontend/features/subscription/providers/subscription_controller.dart';

import 'subscription_fakes.dart';

void main() {
  late FakeSubscriptionRepository repository;
  late FakePurchaseGateway gateway;
  late ProviderContainer container;

  setUp(() {
    repository = FakeSubscriptionRepository();
    gateway = FakePurchaseGateway();
    container = ProviderContainer(overrides: [
      subscriptionRepositoryProvider.overrideWithValue(repository),
      purchaseGatewayProvider.overrideWithValue(gateway),
    ]);
  });

  tearDown(() => container.dispose());

  SubscriptionController controller() => container.read(subscriptionControllerProvider.notifier);

  test('load fetches overview and plans', () async {
    await controller().load();
    final state = container.read(subscriptionControllerProvider);

    expect(state.overview!.planKey, 'free');
    expect(state.plans.map((p) => p.key), ['free', 'love']);
    expect(state.currentPlan!.key, 'free');
  });

  test('purchase goes intent → store → server verification; only the token is sent', () async {
    await controller().load();
    final plan = container.read(subscriptionControllerProvider).plans[1];

    final outcome = await controller().purchase(plan);

    expect(outcome, isA<BillingSucceeded>());
    expect(repository.calls, ['intent:love:mock', 'verify:love_monthly:tok_123']);
    expect(container.read(subscriptionControllerProvider).overview!.planKey, 'love');
    expect(container.read(subscriptionControllerProvider).busy, isFalse);
  });

  test('closing the store sheet changes nothing', () async {
    await controller().load();
    gateway.dismiss = true;

    final outcome = await controller().purchase(container.read(subscriptionControllerProvider).plans[1]);

    expect(outcome, isA<BillingDismissed>());
    expect(repository.calls, ['intent:love:mock']);
    expect(container.read(subscriptionControllerProvider).overview!.planKey, 'free');
  });

  test('a rejected verification is reported, never shown as success', () async {
    await controller().load();
    repository.failVerify = const BillingFailure('The store could not confirm this purchase.', code: 'purchase_invalid');

    final outcome = await controller().purchase(container.read(subscriptionControllerProvider).plans[1]);

    expect(outcome, isA<BillingFailed>().having((f) => f.code, 'code', 'purchase_invalid'));
    expect(container.read(subscriptionControllerProvider).overview!.planKey, 'free');
  });

  test('builds without a store integration cannot purchase', () async {
    gateway.provider = null;
    await controller().load();

    expect(controller().canPurchase, isFalse);
    final outcome = await controller().purchase(container.read(subscriptionControllerProvider).plans[1]);
    expect(outcome, isA<BillingFailed>().having((f) => f.message, 'message', UnavailablePurchaseGateway.message));
    expect(repository.calls, isEmpty);
  });

  test('cancel renewal keeps the plan until period end', () async {
    repository.current = overview(planKey: 'love', subscription: subscriptionJson());
    await controller().load();

    final outcome = await controller().cancelRenewal();

    expect(outcome, isA<BillingSucceeded>());
    final subscription = container.read(subscriptionControllerProvider).overview!.subscription!;
    expect(subscription.status, 'cancelled');
    expect(container.read(subscriptionControllerProvider).overview!.planKey, 'love');
  });

  test('partner cancel refusal is surfaced with its reason', () async {
    repository.current = overview(planKey: 'love', subscription: subscriptionJson(startedBy: 'partner', canManage: false));
    repository.failCancel = const BillingFailure('Only the partner who started the subscription can cancel it.', code: 'not_purchaser');
    await controller().load();

    final outcome = await controller().cancelRenewal();

    expect(outcome, isA<BillingFailed>().having((f) => f.code, 'code', 'not_purchaser'));
  });
}
