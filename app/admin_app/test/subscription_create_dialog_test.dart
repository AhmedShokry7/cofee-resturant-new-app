import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/theme_class.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription_options.dart';
import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription_usage.dart';
import 'package:admin_app/features/subscriptions_admin/domain/repositories/subscription_repository.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/manager/admin_subscription_cubit.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/widgets/create_subscription_dialog.dart';

class _FakeRepository implements SubscriptionRepository {
  _FakeRepository({
    this.planPrice = 120,
    this.createOutcome = AdminCreateSubscriptionOutcome.created,
  });

  final double planPrice;
  final AdminCreateSubscriptionOutcome createOutcome;
  String? createdCustomer;
  String? createdPlan;
  String? createdMethod;
  bool? paymentConfirmed;
  int createCalls = 0;

  @override
  Future<List<AdminSubscription>> loadSubscriptions() async => const [];

  @override
  Future<List<AdminSubscriptionCustomer>> searchCustomers(String query) async =>
      const [
        AdminSubscriptionCustomer(
          id: 'customer-1',
          fullName: 'Sara Ali',
          email: 'sara@example.com',
          phone: '+966500000000',
        ),
      ];

  @override
  Future<List<AdminSubscriptionPaymentMethod>> loadPaymentMethods() async =>
      const [
        AdminSubscriptionPaymentMethod(
          id: 'cash-id',
          code: 'cash',
          nameAr: 'نقدًا',
          nameEn: 'Cash',
        ),
      ];

  @override
  Future<List<AdminSubscriptionPlan>> loadAvailablePlans() async => [
    AdminSubscriptionPlan(
      id: 'plan-1',
      nameAr: 'الخطة الذهبية',
      nameEn: 'Gold plan',
      price: planPrice,
      currencyCode: 'SAR',
      durationDays: 30,
      cupsPerCycle: 20,
    ),
  ];

  @override
  Future<AdminCreateSubscriptionOutcome> createSubscription({
    required String customerId,
    required String planId,
    required String? paymentMethodId,
    required bool paymentConfirmed,
    required String idempotencyKey,
  }) async {
    createCalls++;
    createdCustomer = customerId;
    createdPlan = planId;
    createdMethod = paymentMethodId;
    this.paymentConfirmed = paymentConfirmed;
    return createOutcome;
  }

  @override
  Future<List<AdminSubscriptionUsage>> loadUsage(String subscriptionId) async =>
      const [];

  @override
  Future<SubscriptionCancelOutcome> cancelSubscription(
    String subscriptionId,
  ) async => SubscriptionCancelOutcome.cancelled;

  @override
  Future<SubscriptionRemoveOutcome> removeSubscription(
    String subscriptionId,
  ) async => SubscriptionRemoveOutcome.removed;
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  Future<(_FakeRepository, AdminSubscriptionCubit)> openDialog(
    WidgetTester tester, {
    double price = 120,
  }) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeRepository(planPrice: price);
    final cubit = AdminSubscriptionCubit(repository: repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeClass.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showCreateSubscriptionDialog(
                  context: context,
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
    return (repository, cubit);
  }

  testWidgets('requires confirmed payment before activating a paid plan', (
    tester,
  ) async {
    final (repository, _) = await openDialog(tester);

    expect(find.text(S.subscriptionsCreateTitle), findsOneWidget);
    expect(find.text(S.subscriptionsCashPaymentMethod), findsOneWidget);
    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('create-subscription-submit')),
    );
    expect(submit.onPressed, isNull);

    await tester.tap(find.text('Sara Ali'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('create-subscription-submit')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text(S.subscriptionsCreateConfirmPayment));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('create-subscription-submit')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('create-subscription-submit')));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.createdCustomer, 'customer-1');
    expect(repository.createdPlan, 'plan-1');
    expect(repository.createdMethod, 'cash-id');
    expect(repository.paymentConfirmed, isTrue);
    expect(find.text(S.subscriptionsCreateSuccess), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explains when the database migration is missing', (
    tester,
  ) async {
    final repository = _FakeRepository(
      createOutcome: AdminCreateSubscriptionOutcome.databaseNeedsUpdate,
    );
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = AdminSubscriptionCubit(repository: repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeClass.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showCreateSubscriptionDialog(
                  context: context,
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
    await tester.tap(find.text('Sara Ali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.subscriptionsCreateConfirmPayment));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-subscription-submit')));
    await tester.pumpAndSettle();

    expect(find.text(S.subscriptionsCreateDatabaseNeedsUpdate), findsOneWidget);
    expect(find.text(S.subscriptionsCreateFailed), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('free plans activate without a payment method or confirmation', (
    tester,
  ) async {
    final (repository, _) = await openDialog(tester, price: 0);

    expect(find.text(S.subscriptionsCreateFreePlanHint), findsOneWidget);
    expect(find.text(S.subscriptionsCreateConfirmPayment), findsNothing);
    await tester.tap(find.text('Sara Ali'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-subscription-submit')));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.createdMethod, isNull);
    expect(repository.paymentConfirmed, isFalse);
    expect(tester.takeException(), isNull);
  });
}
