import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/subscription/data/purchase_gateway.dart';
import 'package:frontend/features/subscription/data/subscription_models.dart';
import 'package:frontend/features/subscription/data/subscription_repository.dart';

const gib = 1024 * 1024 * 1024;

Map<String, dynamic> planJson(
  String key,
  String name,
  int price,
  int storageGib, {
  bool current = false,
  bool themes = false,
}) => {
  'key': key,
  'name': name,
  'description': '$name plan',
  'is_free': price == 0,
  'is_current': current,
  'version': 1,
  'price_amount': price,
  'currency': 'IDR',
  'billing_interval': price == 0 ? 'none' : 'month',
  'billing_interval_count': 1,
  'auto_renews': price != 0,
  'storage_limit_bytes': storageGib * gib,
  'features': [
    {
      'key': 'storage_limit_bytes',
      'name': 'Photo storage',
      'type': 'bytes',
      'value': storageGib * gib,
    },
    {
      'key': 'premium_themes',
      'name': 'Premium themes',
      'type': 'boolean',
      'value': themes,
    },
  ],
  'products': price == 0 ? <String, String>{} : {'mock': '${key}_monthly'},
};

Map<String, dynamic> storageJson({int used = 0, int limit = gib}) => {
  'used_bytes': used,
  'trash_bytes': 0,
  'reserved_bytes': 0,
  'limit_bytes': limit,
  'remaining_bytes': (limit - used).clamp(0, limit),
  'is_full': used >= limit,
  'photo_count': 3,
};

Map<String, dynamic> subscriptionJson({
  String status = 'active',
  bool autoRenew = true,
  String startedBy = 'me',
  bool canManage = true,
}) => {
  'id': 1,
  'status': status,
  'is_entitled': true,
  'plan': {'key': 'love', 'name': 'Love'},
  'price_amount': 29000,
  'currency': 'IDR',
  'billing_interval': 'month',
  'billing_interval_count': 1,
  'provider': 'mock',
  'auto_renew': autoRenew,
  'current_period_end': '2026-12-07T10:00:00.000000Z',
  'renews_at': autoRenew ? '2026-12-07T10:00:00.000000Z' : null,
  'benefits_end_at': autoRenew ? null : '2026-12-07T10:00:00.000000Z',
  'grace_ends_at': null,
  'started_by': startedBy,
  'can_manage': canManage,
  'management_url': null,
};

SubscriptionOverview overview({
  Map<String, dynamic>? subscription,
  Map<String, dynamic>? storage,
  String planKey = 'free',
}) => SubscriptionOverview.fromJson({
  'plan_key': planKey,
  'subscription': subscription,
  'entitlements': {
    'storage_limit_bytes': gib,
    'premium_themes': planKey != 'free',
  },
  'storage': storage ?? storageJson(),
  'available_providers': ['mock'],
});

class FakeSubscriptionRepository extends SubscriptionRepository {
  FakeSubscriptionRepository() : super(ApiClient());

  SubscriptionOverview current = overview();
  final calls = <String>[];
  BillingFailure? failVerify;
  BillingFailure? failCancel;

  List<SubscriptionPlan> get plans => [
    SubscriptionPlan.fromJson(
      planJson('free', 'Free', 0, 1, current: current.planKey == 'free'),
    ),
    SubscriptionPlan.fromJson(
      planJson(
        'love',
        'Love',
        29000,
        20,
        current: current.planKey == 'love',
        themes: true,
      ),
    ),
  ];

  @override
  Future<List<SubscriptionPlan>> getPlans() async => plans;

  @override
  Future<SubscriptionOverview> getOverview() async => current;

  @override
  Future<List<BillingTransaction>> getTransactions() async => [
    BillingTransaction.fromJson({
      'id': 1,
      'type': 'purchase',
      'amount': 29000,
      'currency': 'IDR',
      'occurred_at': '2026-11-07T10:00:00Z',
      'plan_name': 'Love',
      'is_test': true,
    }),
  ];

  @override
  Future<PurchaseIntent> createIntent({
    required String planKey,
    required String provider,
  }) async {
    calls.add('intent:$planKey:$provider');
    return PurchaseIntent(
      provider: provider,
      productId: '${planKey}_monthly',
      accountToken: 'acct',
    );
  }

  @override
  Future<SubscriptionOverview> verifyPurchase({
    required String provider,
    required String productId,
    required String purchaseToken,
  }) async {
    calls.add('verify:$productId:$purchaseToken');
    if (failVerify != null) throw failVerify!;
    current = overview(planKey: 'love', subscription: subscriptionJson());
    return current;
  }

  @override
  Future<SubscriptionOverview> cancelRenewal() async {
    calls.add('cancel');
    if (failCancel != null) throw failCancel!;
    current = overview(
      planKey: 'love',
      subscription: subscriptionJson(status: 'cancelled', autoRenew: false),
    );
    return current;
  }
}

class FakePurchaseGateway implements PurchaseGateway {
  bool dismiss = false;

  @override
  String? provider = 'mock';

  @override
  Future<StorePurchase?> buy(PurchaseIntent intent) async => dismiss
      ? null
      : StorePurchase(productId: intent.productId, purchaseToken: 'tok_123');

  @override
  Future<List<StorePurchase>> restorable() async => const [];
}
