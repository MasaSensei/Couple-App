import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/network/api_client.dart';

import '../data/purchase_gateway.dart';
import '../data/subscription_models.dart';
import '../data/subscription_repository.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepository(ApiClient()),
);

/// Debug builds use the server's mock store; release builds have no real
/// store integration yet and say so instead of faking a purchase.
final purchaseGatewayProvider = Provider<PurchaseGateway>(
  (ref) => kDebugMode
      ? MockPurchaseGateway(ApiClient())
      : const UnavailablePurchaseGateway(),
);

final subscriptionControllerProvider =
    NotifierProvider<SubscriptionController, SubscriptionState>(
      SubscriptionController.new,
    );

@immutable
class SubscriptionState {
  const SubscriptionState({
    this.overview,
    this.plans = const [],
    this.transactions,
    this.loading = false,
    this.busy = false,
    this.error,
  });

  final SubscriptionOverview? overview;
  final List<SubscriptionPlan> plans;
  final List<BillingTransaction>? transactions;
  final bool loading;

  /// A purchase / cancel / restore is in flight.
  final bool busy;
  final String? error;

  SubscriptionPlan? get currentPlan {
    final key = overview?.planKey;
    for (final plan in plans) {
      if (plan.key == key) return plan;
    }
    return null;
  }

  SubscriptionState copyWith({
    SubscriptionOverview? overview,
    List<SubscriptionPlan>? plans,
    List<BillingTransaction>? transactions,
    bool? loading,
    bool? busy,
    String? error,
    bool clearError = false,
  }) => SubscriptionState(
    overview: overview ?? this.overview,
    plans: plans ?? this.plans,
    transactions: transactions ?? this.transactions,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
  );
}

sealed class BillingOutcome {
  const BillingOutcome();
}

class BillingSucceeded extends BillingOutcome {
  const BillingSucceeded(this.message);
  final String message;
}

/// The user closed the store sheet; nothing happened.
class BillingDismissed extends BillingOutcome {
  const BillingDismissed();
}

class BillingFailed extends BillingOutcome {
  const BillingFailed(this.message, {this.code, this.managementUrl});
  final String message;
  final String? code;
  final String? managementUrl;
}

class SubscriptionController extends Notifier<SubscriptionState> {
  SubscriptionRepository get _repository =>
      ref.read(subscriptionRepositoryProvider);
  PurchaseGateway get _gateway => ref.read(purchaseGatewayProvider);

  @override
  SubscriptionState build() => const SubscriptionState();

  /// Purchases work only when this build has a store AND the server accepts it.
  bool get canPurchase {
    final provider = _gateway.provider;
    return provider != null &&
        (state.overview?.availableProviders.contains(provider) ?? false);
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final results = await Future.wait([
        _repository.getOverview(),
        _repository.getPlans(),
      ]);
      state = state.copyWith(
        overview: results[0] as SubscriptionOverview,
        plans: results[1] as List<SubscriptionPlan>,
        loading: false,
      );
    } on BillingFailure catch (failure) {
      state = state.copyWith(loading: false, error: failure.message);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Unable to load your plan right now.',
      );
    }
  }

  Future<void> loadTransactions() async {
    try {
      state = state.copyWith(transactions: await _repository.getTransactions());
    } catch (_) {
      state = state.copyWith(transactions: const []);
    }
  }

  /// intent (server) → store sheet → server-side verification.
  Future<BillingOutcome> purchase(SubscriptionPlan plan) => _run(() async {
    final provider = _gateway.provider;
    if (provider == null || !canPurchase) {
      return const BillingFailed(
        UnavailablePurchaseGateway.message,
        code: 'provider_unavailable',
      );
    }

    final intent = await _repository.createIntent(
      planKey: plan.key,
      provider: provider,
    );
    final purchase = await _gateway.buy(intent);
    if (purchase == null) return const BillingDismissed();

    final overview = await _repository.verifyPurchase(
      provider: provider,
      productId: purchase.productId,
      purchaseToken: purchase.purchaseToken,
    );
    await _refreshAfter(overview);
    return BillingSucceeded('${plan.name} is now active for both of you');
  });

  Future<BillingOutcome> cancelRenewal() => _run(() async {
    final overview = await _repository.cancelRenewal();
    await _refreshAfter(overview);
    final end = overview.subscription?.benefitsEndAt;
    return BillingSucceeded(
      end == null ? 'Auto-renew is off.' : 'Auto-renew is off. Your benefits continue until the end of the paid period.',
    );
  });

  Future<BillingOutcome> restore() => _run(() async {
    final provider = _gateway.provider;
    if (provider == null) {
      return const BillingFailed(
        UnavailablePurchaseGateway.message,
        code: 'provider_unavailable',
      );
    }
    final purchases = await _gateway.restorable();
    if (purchases.isEmpty) {
      return const BillingSucceeded('No purchases to restore on this device.');
    }

    final overview = await _repository.restore(
      provider: provider,
      purchases: purchases,
    );
    await _refreshAfter(overview);
    return const BillingSucceeded('Purchases checked with the store.');
  });

  Future<void> _refreshAfter(SubscriptionOverview overview) async {
    state = state.copyWith(overview: overview);
    try {
      state = state.copyWith(plans: await _repository.getPlans());
    } catch (_) {
      // Plans list refreshes next time; the overview is already current.
    }
  }

  Future<BillingOutcome> _run(Future<BillingOutcome> Function() action) async {
    if (state.busy) {
      return const BillingFailed(
        'Please wait for the current request to finish.',
      );
    }
    state = state.copyWith(busy: true);
    try {
      return await action();
    } on BillingFailure catch (failure) {
      return BillingFailed(
        failure.message,
        code: failure.code,
        managementUrl: failure.data?['management_url'] as String?,
      );
    } catch (_) {
      return const BillingFailed(
        'Something went wrong. Please try again. If the store charged you, use "Restore purchases".',
      );
    } finally {
      state = state.copyWith(busy: false);
    }
  }
}
