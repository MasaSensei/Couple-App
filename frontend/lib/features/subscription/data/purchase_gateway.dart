import 'package:frontend/core/error/api_exception.dart';
import 'package:frontend/core/network/api_client.dart';

import 'subscription_models.dart';
import 'subscription_repository.dart';

/// The platform store's purchase sheet (Google Play Billing / StoreKit).
///
/// Only the development mock is implemented. Real Google Play / App Store
/// purchases need the `in_app_purchase` plugin and store accounts, which are
/// not set up yet (docs/billing/subscriptions.md §9), so release builds use
/// [UnavailablePurchaseGateway] and say so honestly instead of pretending.
abstract class PurchaseGateway {
  /// Provider key sent to the server, or null when purchases are unavailable.
  String? get provider;

  /// Shows the store's purchase sheet. Returns null when the user closes it.
  Future<StorePurchase?> buy(PurchaseIntent intent);

  /// Purchases the store still knows on this device (for "Restore").
  Future<List<StorePurchase>> restorable();
}

class UnavailablePurchaseGateway implements PurchaseGateway {
  const UnavailablePurchaseGateway();

  static const message =
      'In-app purchases are not available in this version yet.';

  @override
  String? get provider => null;

  @override
  Future<StorePurchase?> buy(PurchaseIntent intent) async =>
      throw const BillingFailure(message, code: 'provider_unavailable');

  @override
  Future<List<StorePurchase>> restorable() async => const [];
}

/// Development stand-in for the store sheet, backed by the server's mock
/// store (only reachable when the server enables it; never in production).
class MockPurchaseGateway implements PurchaseGateway {
  MockPurchaseGateway(this._apiClient);

  final ApiClient _apiClient;
  final List<StorePurchase> _bought = [];

  @override
  String get provider => 'mock';

  @override
  Future<StorePurchase?> buy(PurchaseIntent intent) async {
    try {
      final response = await _apiClient.post(
        '/billing/mock/purchases',
        data: {
          'product_id': intent.productId,
          'account_token': intent.accountToken,
          'replaces_subscription_id': intent.replacesSubscriptionId,
        },
      );
      final data = Map<String, dynamic>.from(response.data['data'] as Map);
      final purchase = StorePurchase(
        productId: data['product_id'] as String,
        purchaseToken: data['purchase_token'] as String,
      );
      _bought.add(purchase);
      return purchase;
    } on ApiException catch (error) {
      throw BillingFailure(error.message, code: 'store_error');
    }
  }

  @override
  Future<List<StorePurchase>> restorable() async => List.unmodifiable(_bought);
}
