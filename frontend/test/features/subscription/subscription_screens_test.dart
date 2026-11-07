import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/subscription/presentation/plan_comparison_screen.dart';
import 'package:frontend/features/subscription/presentation/storage_screen.dart';
import 'package:frontend/features/subscription/presentation/subscription_management_screen.dart';
import 'package:frontend/features/subscription/presentation/subscription_overview_screen.dart';
import 'package:frontend/features/subscription/providers/subscription_controller.dart';

import 'subscription_fakes.dart';

void main() {
  late FakeSubscriptionRepository repository;
  late FakePurchaseGateway gateway;

  setUp(() {
    repository = FakeSubscriptionRepository();
    gateway = FakePurchaseGateway();
  });

  Widget app(Widget screen) => ProviderScope(
    overrides: [
      subscriptionRepositoryProvider.overrideWithValue(repository),
      purchaseGatewayProvider.overrideWithValue(gateway),
    ],
    child: MaterialApp(home: screen),
  );

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(screen));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'overview shows the current plan, storage and the always-included promise',
    (tester) async {
      repository.current = overview(storage: storageJson(used: gib ~/ 2));
      await pump(tester, const SubscriptionOverviewScreen());

      expect(find.text('Free'), findsOneWidget);
      expect(find.text('512 MB of 1 GB used'), findsOneWidget);
      expect(
        find.textContaining('end-to-end encrypted photos'),
        findsOneWidget,
      );
      expect(find.text('Compare plans'), findsOneWidget);
    },
  );

  testWidgets('overview explains auto-renewal of an active subscription', (
    tester,
  ) async {
    repository.current = overview(
      planKey: 'love',
      subscription: subscriptionJson(),
    );
    await pump(tester, const SubscriptionOverviewScreen());

    expect(find.text('Love'), findsWidgets);
    expect(find.text('Rp 29.000 per month'), findsOneWidget);
    expect(
      find.textContaining('Renews automatically on 7 Dec 2026'),
      findsOneWidget,
    );
  });

  testWidgets(
    'plan comparison shows prices, renewal terms and confirms before paying',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(repository),
          purchaseGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);
      await container.read(subscriptionControllerProvider.notifier).load();

      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PlanComparisonScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rp 29.000 per month'), findsOneWidget);
      expect(
        find.textContaining(
          'Renews automatically every month at the same price until you cancel',
        ),
        findsOneWidget,
      );
      expect(find.text('Current'), findsOneWidget);

      await tester.tap(find.text('Choose Love'));
      await tester.pumpAndSettle();
      expect(find.text('Subscribe to Love?'), findsOneWidget);
      expect(
        repository.calls,
        isEmpty,
        reason: 'nothing happens before confirmation',
      );

      await tester.tap(find.text('Continue to payment'));
      await tester.pumpAndSettle();
      expect(repository.calls, [
        'intent:love:mock',
        'verify:love_monthly:tok_123',
      ]);
    },
  );

  testWidgets(
    'purchase buttons are disabled with an honest note when the store is unavailable',
    (tester) async {
      gateway.provider = null;
      await pump(tester, const PlanComparisonScreen());

      expect(
        find.text('In-app purchases are not available in this version yet.'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Choose Love'),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets('purchaser sees a plain cancel button and history', (
    tester,
  ) async {
    repository.current = overview(
      planKey: 'love',
      subscription: subscriptionJson(),
    );
    final container = ProviderContainer(
      overrides: [
        subscriptionRepositoryProvider.overrideWithValue(repository),
        purchaseGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    await container.read(subscriptionControllerProvider.notifier).load();

    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SubscriptionManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cancel auto-renew'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.textContaining('Purchase · Love'), findsOneWidget);

    await tester.tap(find.text('Cancel auto-renew'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Your photos and memories are not deleted'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel auto-renew'));
    await tester.pumpAndSettle();

    expect(repository.calls, ['cancel']);
    expect(
      find.textContaining('Benefits continue until 7 Dec 2026'),
      findsOneWidget,
    );
  });

  testWidgets('partner sees who manages billing instead of a cancel button', (
    tester,
  ) async {
    repository.current = overview(
      planKey: 'love',
      subscription: subscriptionJson(startedBy: 'partner', canManage: false),
    );
    final container = ProviderContainer(
      overrides: [
        subscriptionRepositoryProvider.overrideWithValue(repository),
        purchaseGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    await container.read(subscriptionControllerProvider.notifier).load();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SubscriptionManagementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cancel auto-renew'), findsNothing);
    expect(find.textContaining('Your partner manages billing'), findsOneWidget);
  });

  testWidgets('full storage explains what still works', (tester) async {
    await pump(
      tester,
      Scaffold(
        body: StorageDetails(
          storage: overview(storage: storageJson(used: 2 * gib)).storage,
        ),
      ),
    );

    expect(find.text('Your storage is full'), findsOneWidget);
    expect(find.textContaining('Nothing was deleted'), findsOneWidget);
    expect(
      find.textContaining(
        'You can still open, download and delete every photo',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('backup copy is never counted'), findsOneWidget);
  });
}
