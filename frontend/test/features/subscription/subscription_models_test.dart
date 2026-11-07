import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/subscription/data/subscription_models.dart';
import 'package:frontend/features/subscription/presentation/billing_format.dart';

import 'subscription_fakes.dart';

void main() {
  test('plan parses price, interval, features and products', () {
    final plan = SubscriptionPlan.fromJson(planJson('love', 'Love', 29000, 20, themes: true));

    expect(plan.priceAmount, 29000);
    expect(plan.billingInterval, 'month');
    expect(plan.autoRenews, isTrue);
    expect(plan.storageLimitBytes, 20 * gib);
    expect(plan.features.map((f) => f.included), [true, true]);
    expect(plan.products, {'mock': 'love_monthly'});
  });

  test('overview parses subscription, storage and entitlements', () {
    final o = overview(planKey: 'love', subscription: subscriptionJson(status: 'cancelled', autoRenew: false), storage: storageJson(used: 2 * gib));

    expect(o.allows('premium_themes'), isTrue);
    expect(o.subscription!.status, 'cancelled');
    expect(o.subscription!.renewsAt, isNull);
    expect(o.subscription!.benefitsEndAt, isNotNull);
    expect(o.storage.isFull, isTrue);
    expect(o.storage.isOverLimit, isTrue);
    expect(o.storage.fraction, 1.0);
  });

  test('prices are shown in full with their interval', () {
    expect(BillingFormat.price(29000, 'IDR'), 'Rp 29.000');
    expect(BillingFormat.price(-29000, 'IDR'), '−Rp 29.000');
    expect(BillingFormat.price(499, 'USD'), 'USD 4.99');
    expect(BillingFormat.priceWithInterval(29000, 'IDR', 'month', 1), 'Rp 29.000 per month');
    expect(BillingFormat.priceWithInterval(290000, 'IDR', 'year', 1), 'Rp 290.000 per year');
    expect(BillingFormat.priceWithInterval(0, 'IDR', 'none', 1), 'Free');
    expect(BillingFormat.interval('month', 3), 'every 3 months');
  });

  test('bytes are human readable', () {
    expect(BillingFormat.bytes(512), '512 B');
    expect(BillingFormat.bytes(1536), '1.5 KB');
    expect(BillingFormat.bytes(gib), '1 GB');
    expect(BillingFormat.bytes(20 * gib), '20 GB');
  });
}
