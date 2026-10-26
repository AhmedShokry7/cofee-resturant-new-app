import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/subscriptions_admin/data/models/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/data/models/admin_subscription_usage.dart';
import 'package:admin_app/features/subscriptions_admin/data/repositories/admin_subscription_repository.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/manager/admin_subscription_cubit.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/widgets/subscription_details_dialog.dart';

AdminSubscription _subscription({
  String status = 'active',
  int reserved = 0,
  DateTime? endsAt,
}) => AdminSubscription(
  id: 's1',
  customerName: 'Sara Ali',
  customerEmail: 'sara@example.com',
  customerPhone: '+966500000000',
  planNameAr: 'الخطة الذهبية',
  planNameEn: 'Gold plan',
  planCode: 'gold',
  planPrice: 120,
  currencyCode: 'SAR',
  planDurationDays: 30,
  status: status,
  startsAt: DateTime(2026, 10, 1),
  endsAt: endsAt ?? DateTime(2030, 1, 1),
  cupsEntitled: 20,
  cupsUsed: 5,
  cupsCarriedOver: 2,
  cupsReserved: reserved,
  autoRenew: true,
  paymentReference: 'pay_123',
  createdAt: DateTime(2026, 9, 30),
  usageCount: 3,
  lastUsedAt: DateTime(2026, 10, 20),
);

class _FakeRepository extends AdminSubscriptionRepository {
  _FakeRepository({
    this.usage = const <AdminSubscriptionUsage>[],
    this.outcome = SubscriptionCancelOutcome.cancelled,
    this.usageError,
  });

  final List<AdminSubscriptionUsage> usage;
  SubscriptionCancelOutcome outcome;
  final Object? usageError;
  int cancelCalls = 0;

  @override
  Future<List<AdminSubscription>> loadSubscriptions() async =>
      const <AdminSubscription>[];

  @override
  Future<List<AdminSubscriptionUsage>> loadUsage(String subscriptionId) async {
    if (usageError != null) throw usageError!;
    return usage;
  }

  @override
  Future<SubscriptionCancelOutcome> cancelSubscription(
    String subscriptionId,
  ) async {
    cancelCalls++;
    return outcome;
  }
}

Future<AdminSubscriptionCubit> _openDialog(
  WidgetTester tester, {
  required AdminSubscription subscription,
  _FakeRepository? repository,
  Size size = const Size(1280, 900),
  bool dark = false,
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final cubit = AdminSubscriptionCubit(
    repository: repository ?? _FakeRepository(),
  );
  addTearDown(cubit.close);

  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeClass.dark() : ThemeClass.light(),
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showSubscriptionDetailsDialog(
                context: context,
                subscription: subscription,
                cubit: cubit,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('shows the real customer, plan, cups and usage details', (
    tester,
  ) async {
    await _openDialog(
      tester,
      subscription: _subscription(),
      repository: _FakeRepository(
        usage: [
          AdminSubscriptionUsage(
            id: 'u1',
            quantity: 2,
            method: 'qr',
            createdAt: DateTime(2026, 10, 20, 9, 30),
            branchNameAr: 'الفرع الرئيسي',
            branchNameEn: 'Main branch',
            productNameAr: 'لاتيه',
            productNameEn: 'Latte',
            orderNumber: 'ORD-1001',
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.subscriptionsDetailsTitle), findsOneWidget);
    expect(find.text('Sara Ali'), findsOneWidget);
    expect(find.text('Gold plan'), findsNWidgets(2));
    expect(find.text(S.subscriptionStatusExpiringSoon), findsNothing);
    expect(find.text(S.subscriptionsCupsRemaining), findsWidgets);
    expect(find.text(S.subscriptionsUsageRedemptions), findsOneWidget);
    expect(find.text(S.subscriptionsUsageCountLabel(3)), findsOneWidget);
    expect(find.text(S.subscriptionsUsageMethodQr), findsOneWidget);
    expect(find.text('17 / 22'), findsOneWidget);
    expect(find.text('Latte • Main branch'), findsOneWidget);
    expect(find.text('${S.orderNumber}: ORD-1001'), findsOneWidget);
    expect(find.text(S.subscriptionsUsageLimited(1, 3)), findsOneWidget);
  });

  testWidgets('a pending subscription explains that no cups were issued', (
    tester,
  ) async {
    await _openDialog(
      tester,
      subscription: _subscription(status: 'pending_payment'),
    );

    expect(find.text(S.subscriptionStatusPendingPayment), findsOneWidget);
    await tester.tap(find.text(S.subscriptionsCancelAction));
    await tester.pumpAndSettle();

    expect(find.text(S.subscriptionsCancelPendingMessage), findsOneWidget);
    expect(find.text(S.subscriptionsCancelMessage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed usage load offers a retry', (tester) async {
    await _openDialog(
      tester,
      subscription: _subscription(),
      repository: _FakeRepository(usageError: StateError('offline')),
    );

    expect(find.text(S.subscriptionsUsageLoadFailed), findsOneWidget);
    expect(find.text(S.tryAgain), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an expiring subscription is flagged as expiring soon', (
    tester,
  ) async {
    await _openDialog(
      tester,
      subscription: _subscription(
        endsAt: DateTime.now().add(const Duration(days: 3)),
      ),
    );

    expect(find.text(S.subscriptionStatusExpiringSoon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an expired subscription has no cancel action', (tester) async {
    await _openDialog(tester, subscription: _subscription(status: 'expired'));

    expect(find.text(S.subscriptionsCancelAction), findsNothing);
    expect(find.text(S.close), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reserved cups disable the cancel action and explain why', (
    tester,
  ) async {
    await _openDialog(tester, subscription: _subscription(reserved: 2));

    expect(find.byTooltip(S.subscriptionsCancelReserved), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text(S.subscriptionsCancelAction),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling asks for confirmation and reports the outcome', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _openDialog(
      tester,
      subscription: _subscription(),
      repository: repository,
    );

    await tester.tap(find.text(S.subscriptionsCancelAction));
    await tester.pumpAndSettle();
    expect(find.text(S.subscriptionsCancelTitle), findsOneWidget);
    expect(find.text(S.subscriptionsCancelMessage), findsOneWidget);

    await tester.tap(find.text(S.subscriptionsCancelConfirm));
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, 1);
    expect(find.text(S.subscriptionsDetailsTitle), findsNothing);
    expect(find.text(S.subscriptionsCancelledSuccess), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a blocked cancellation keeps the dialog and explains why', (
    tester,
  ) async {
    final repository = _FakeRepository(
      outcome: SubscriptionCancelOutcome.reservedCups,
    );
    await _openDialog(
      tester,
      subscription: _subscription(),
      repository: repository,
    );

    await tester.tap(find.text(S.subscriptionsCancelAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.subscriptionsCancelConfirm));
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, 1);
    expect(find.text(S.subscriptionsDetailsTitle), findsOneWidget);
    expect(find.text(S.subscriptionsCancelReserved), findsWidgets);
  });

  testWidgets('the narrow Arabic dialog fits', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    await _openDialog(
      tester,
      subscription: _subscription(),
      size: const Size(380, 900),
      direction: TextDirection.rtl,
    );

    expect(tester.takeException(), isNull);
    expect(find.text(S.subscriptionsDetailsTitle), findsOneWidget);
  });

  testWidgets('the dark dialog fits', (tester) async {
    await _openDialog(tester, subscription: _subscription(), dark: true);

    expect(tester.takeException(), isNull);
    expect(find.text(S.subscriptionsDetailsTitle), findsOneWidget);
  });
}
