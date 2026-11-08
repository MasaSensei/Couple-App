import 'package:flutter/foundation.dart';

/// Everything here is display data from the server. The app never decides
/// what a couple is entitled to: the backend enforces every limit, and these
/// values only drive what is shown.

@immutable
class PlanFeature {
  const PlanFeature({
    required this.key,
    required this.name,
    this.description,
    required this.type,
    required this.value,
  });

  final String key;
  final String name;
  final String? description;

  /// `boolean` | `bytes` | `integer`
  final String type;
  final Object? value;

  bool get included =>
      type == 'boolean' ? value == true : ((value as num?) ?? 0) > 0;

  factory PlanFeature.fromJson(Map<String, dynamic> json) => PlanFeature(
    key: json['key'] as String,
    name: json['name'] as String? ?? json['key'] as String,
    description: json['description'] as String?,
    type: json['type'] as String? ?? 'boolean',
    value: json['value'],
  );
}

@immutable
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.key,
    required this.name,
    this.description,
    required this.isFree,
    required this.isCurrent,
    required this.version,
    required this.priceAmount,
    required this.currency,
    required this.billingInterval,
    required this.billingIntervalCount,
    required this.autoRenews,
    required this.storageLimitBytes,
    required this.features,
    required this.products,
  });

  final String key;
  final String name;
  final String? description;
  final bool isFree;
  final bool isCurrent;
  final int version;
  final int priceAmount;
  final String currency;

  /// `none` | `month` | `year`
  final String billingInterval;
  final int billingIntervalCount;
  final bool autoRenews;
  final int storageLimitBytes;
  final List<PlanFeature> features;

  /// Store product id per enabled provider (e.g. {'mock': 'love_monthly'}).
  final Map<String, String> products;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlan(
        key: json['key'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        isFree: json['is_free'] as bool? ?? false,
        isCurrent: json['is_current'] as bool? ?? false,
        version: (json['version'] as num?)?.toInt() ?? 1,
        priceAmount: (json['price_amount'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String? ?? 'IDR',
        billingInterval: json['billing_interval'] as String? ?? 'none',
        billingIntervalCount:
            (json['billing_interval_count'] as num?)?.toInt() ?? 1,
        autoRenews: json['auto_renews'] as bool? ?? false,
        storageLimitBytes: (json['storage_limit_bytes'] as num?)?.toInt() ?? 0,
        features: [
          for (final f in (json['features'] as List? ?? const []))
            PlanFeature.fromJson(Map<String, dynamic>.from(f as Map)),
        ],
        products: (json['products'] is Map)
            ? Map<String, String>.from(
                (json['products'] as Map).map(
                  (k, v) => MapEntry(k as String, v as String),
                ),
              )
            : const {},
      );
}

@immutable
class StorageUsage {
  const StorageUsage({
    required this.usedBytes,
    required this.trashBytes,
    required this.reservedBytes,
    required this.limitBytes,
    required this.remainingBytes,
    required this.isFull,
    required this.photoCount,
  });

  final int usedBytes;
  final int trashBytes;
  final int reservedBytes;
  final int limitBytes;
  final int remainingBytes;
  final bool isFull;
  final int photoCount;

  double get fraction =>
      limitBytes <= 0 ? 1 : (usedBytes / limitBytes).clamp(0, 1).toDouble();

  bool get isOverLimit => usedBytes > limitBytes;

  factory StorageUsage.fromJson(Map<String, dynamic> json) => StorageUsage(
    usedBytes: (json['used_bytes'] as num?)?.toInt() ?? 0,
    trashBytes: (json['trash_bytes'] as num?)?.toInt() ?? 0,
    reservedBytes: (json['reserved_bytes'] as num?)?.toInt() ?? 0,
    limitBytes: (json['limit_bytes'] as num?)?.toInt() ?? 0,
    remainingBytes: (json['remaining_bytes'] as num?)?.toInt() ?? 0,
    isFull: json['is_full'] as bool? ?? false,
    photoCount: (json['photo_count'] as num?)?.toInt() ?? 0,
  );
}

@immutable
class CoupleSubscription {
  const CoupleSubscription({
    required this.status,
    required this.isEntitled,
    required this.planKey,
    required this.planName,
    required this.priceAmount,
    required this.currency,
    required this.billingInterval,
    required this.billingIntervalCount,
    required this.provider,
    required this.autoRenew,
    this.currentPeriodEnd,
    this.renewsAt,
    this.benefitsEndAt,
    this.graceEndsAt,
    required this.startedBy,
    required this.canManage,
    this.managementUrl,
  });

  /// pending | active | grace_period | cancelled | expired | payment_failed | suspended
  final String status;
  final bool isEntitled;
  final String planKey;
  final String planName;
  final int priceAmount;
  final String currency;
  final String billingInterval;
  final int billingIntervalCount;
  final String provider;
  final bool autoRenew;
  final DateTime? currentPeriodEnd;
  final DateTime? renewsAt;
  final DateTime? benefitsEndAt;
  final DateTime? graceEndsAt;

  /// `me` | `partner` | `support`
  final String startedBy;

  /// Only the partner whose store account pays can cancel or change it.
  final bool canManage;
  final String? managementUrl;

  factory CoupleSubscription.fromJson(Map<String, dynamic> json) {
    final plan = Map<String, dynamic>.from(json['plan'] as Map? ?? const {});
    DateTime? date(String key) => json[key] == null
        ? null
        : DateTime.tryParse(json[key] as String)?.toLocal();

    return CoupleSubscription(
      status: json['status'] as String,
      isEntitled: json['is_entitled'] as bool? ?? false,
      planKey: plan['key'] as String? ?? '',
      planName: plan['name'] as String? ?? '',
      priceAmount: (json['price_amount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'IDR',
      billingInterval: json['billing_interval'] as String? ?? 'none',
      billingIntervalCount:
          (json['billing_interval_count'] as num?)?.toInt() ?? 1,
      provider: json['provider'] as String? ?? '',
      autoRenew: json['auto_renew'] as bool? ?? false,
      currentPeriodEnd: date('current_period_end'),
      renewsAt: date('renews_at'),
      benefitsEndAt: date('benefits_end_at'),
      graceEndsAt: date('grace_ends_at'),
      startedBy: json['started_by'] as String? ?? 'partner',
      canManage: json['can_manage'] as bool? ?? false,
      managementUrl: json['management_url'] as String?,
    );
  }
}

@immutable
class SubscriptionOverview {
  const SubscriptionOverview({
    required this.planKey,
    this.subscription,
    required this.entitlements,
    required this.storage,
    required this.availableProviders,
  });

  final String planKey;
  final CoupleSubscription? subscription;
  final Map<String, Object?> entitlements;
  final StorageUsage storage;
  final List<String> availableProviders;

  bool allows(String key) => entitlements[key] == true;

  factory SubscriptionOverview.fromJson(Map<String, dynamic> json) =>
      SubscriptionOverview(
        planKey: json['plan_key'] as String? ?? 'free',
        subscription: json['subscription'] is Map
            ? CoupleSubscription.fromJson(
                Map<String, dynamic>.from(json['subscription'] as Map),
              )
            : null,
        entitlements: Map<String, Object?>.from(
          json['entitlements'] as Map? ?? const {},
        ),
        storage: StorageUsage.fromJson(
          Map<String, dynamic>.from(json['storage'] as Map? ?? const {}),
        ),
        availableProviders: [
          for (final p in (json['available_providers'] as List? ?? const []))
            p as String,
        ],
      );
}

@immutable
class BillingTransaction {
  const BillingTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.occurredAt,
    this.planName,
    required this.isTest,
  });

  final int id;

  /// purchase | renewal | refund | chargeback | adjustment
  final String type;
  final int amount;
  final String currency;
  final DateTime occurredAt;
  final String? planName;
  final bool isTest;

  factory BillingTransaction.fromJson(Map<String, dynamic> json) =>
      BillingTransaction(
        id: (json['id'] as num).toInt(),
        type: json['type'] as String,
        amount: (json['amount'] as num).toInt(),
        currency: json['currency'] as String,
        occurredAt: DateTime.parse(json['occurred_at'] as String).toLocal(),
        planName: json['plan_name'] as String?,
        isTest: json['is_test'] as bool? ?? false,
      );
}

@immutable
class PurchaseIntent {
  const PurchaseIntent({
    required this.provider,
    required this.productId,
    required this.accountToken,
    this.replacesSubscriptionId,
  });

  final String provider;
  final String productId;

  /// Opaque couple id handed to the store, so the purchase can only ever be
  /// linked back to this couple.
  final String accountToken;
  final String? replacesSubscriptionId;

  factory PurchaseIntent.fromJson(Map<String, dynamic> json) => PurchaseIntent(
    provider: json['provider'] as String,
    productId: json['product_id'] as String,
    accountToken: json['account_token'] as String,
    replacesSubscriptionId: json['replaces_subscription_id'] as String?,
  );
}

/// A refused billing request, with the server's stable code.
class BillingFailure implements Exception {
  const BillingFailure(this.message, {this.code, this.data});

  final String message;
  final String? code;
  final Map<String, Object?>? data;

  @override
  String toString() => 'BillingFailure($code, $message)';
}
