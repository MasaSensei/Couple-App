import 'package:frontend/core/error/api_exception.dart';
import 'package:frontend/core/network/api_client.dart';

import 'subscription_models.dart';

class SubscriptionRepository {
  SubscriptionRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<SubscriptionPlan>> getPlans() => _guard(() async {
        final response = await _apiClient.get('/billing/plans');
        final plans = (response.data['data'] as Map)['plans'] as List;
        return [for (final p in plans) SubscriptionPlan.fromJson(Map<String, dynamic>.from(p as Map))];
      });

  Future<SubscriptionOverview> getOverview() => _guard(() async {
        final response = await _apiClient.get('/couple/subscription');
        return _overview(response.data);
      });

  Future<List<BillingTransaction>> getTransactions() => _guard(() async {
        final response = await _apiClient.get('/couple/subscription/transactions');
        final list = (response.data['data'] as Map)['transactions'] as List;
        return [for (final t in list) BillingTransaction.fromJson(Map<String, dynamic>.from(t as Map))];
      });

  Future<PurchaseIntent> createIntent({required String planKey, required String provider}) => _guard(() async {
        final response = await _apiClient.post('/couple/subscription/intents', data: {'plan_key': planKey, 'provider': provider});
        return PurchaseIntent.fromJson(Map<String, dynamic>.from((response.data['data'] as Map)['intent'] as Map));
      });

  /// Sends only the store's opaque token. Status, price and dates are
  /// decided by the server after asking the store.
  Future<SubscriptionOverview> verifyPurchase({
    required String provider,
    required String productId,
    required String purchaseToken,
  }) =>
      _guard(() async {
        final response = await _apiClient.post('/couple/subscription/verify', data: {
          'provider': provider,
          'product_id': productId,
          'purchase_token': purchaseToken,
        });
        return _overview(response.data);
      });

  Future<SubscriptionOverview> restore({required String provider, required List<StorePurchase> purchases}) => _guard(() async {
        final response = await _apiClient.post('/couple/subscription/restore', data: {
          'provider': provider,
          'purchases': [
            for (final p in purchases) {'product_id': p.productId, 'purchase_token': p.purchaseToken},
          ],
        });
        return _overview(response.data);
      });

  Future<SubscriptionOverview> cancelRenewal() => _guard(() async {
        final response = await _apiClient.post('/couple/subscription/cancel');
        return _overview(response.data);
      });

  SubscriptionOverview _overview(Object? body) =>
      SubscriptionOverview.fromJson(Map<String, dynamic>.from((body as Map)['data'] as Map));

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException catch (error) {
      final data = error.data is Map ? Map<String, Object?>.from(error.data as Map) : null;
      throw BillingFailure(error.message, code: data?['code'] as String?, data: data);
    }
  }
}

/// What a store hands back after a purchase: an opaque token, nothing more.
class StorePurchase {
  const StorePurchase({required this.productId, required this.purchaseToken});

  final String productId;
  final String purchaseToken;
}
