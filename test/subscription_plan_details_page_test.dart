import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/payment/data/repositories/tap_payment_repository.dart';
import 'package:new_coffee/features/payment/presentation/views/card_payment_page.dart';
import 'package:new_coffee/features/subscriptions/data/model/customer_subscription.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan_product.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_plan_details_page.dart';
import 'package:new_coffee/shared/utils/formatters.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

/// The plan page is where a customer decides to pay, so every line it prints
/// has to be a sentence they can read and the one button it offers has to
/// charge exactly what is on screen.
class _FakeRepository implements SubscriptionRepository {
  _FakeRepository({this.productsToReturn = const []});

  List<SubscriptionPlanProduct> productsToReturn;

  /// Why the product list refuses, so the page is proved to keep the plan it
  /// already printed.
  Object? productsError;

  /// Why the write refuses, so the page is proved to open no payment for a
  /// subscription it did not create.
  Object? subscribeError;

  /// Holds a subscribe open so a second tap can be made while the first one is
  /// still in flight.
  Completer<CustomerSubscription>? subscribeGate;

  int subscribeCalls = 0;
  int productsCalls = 0;
  String? lastProductsPlanId;

  @override
  Future<List<SubscriptionPlanProduct>> planProducts(String planId) async {
    productsCalls++;
    lastProductsPlanId = planId;
    final error = productsError;
    if (error != null) throw error;
    return productsToReturn;
  }

  @override
  Future<CustomerSubscription> subscribe({
    required String planId,
    required String idempotencyKey,
  }) async {
    subscribeCalls++;
    final gate = subscribeGate;
    if (gate != null) return gate.future;
    final error = subscribeError;
    if (error != null) throw error;
    return CustomerSubscription(id: 'sub-$subscribeCalls', planId: planId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A plan whose columns hold the database's own words, so the page is proved to
/// translate them.
const SubscriptionPlan _plan = SubscriptionPlan(
  id: 'plan-1',
  code: 'monthly',
  nameAr: 'الباقة الشهرية',
  nameEn: 'Monthly plan',
  descriptionEn: 'Sixty cups a month',
  price: 149,
  currencyCode: 'SAR',
  durationDays: 30,
  cupsPerCycle: 60,
  rolloverCapCups: 10,
  renewalPolicy: 'auto',
  productScope: 'all',
);

const SubscriptionPlan _selectedProductsPlan = SubscriptionPlan(
  id: 'plan-2',
  code: 'latte',
  nameAr: 'باقة اللاتيه',
  nameEn: 'Latte plan',
  price: 99,
  productScope: 'selected',
  bonusType: 'credit',
  bonusValue: 25,
);

void _setSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1400) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(
  WidgetTester tester,
  SubscriptionRepository repo,
  SubscriptionPlan plan,
) async {
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SubscriptionRepository>.value(value: repo),
        RepositoryProvider<TapPaymentRepository>(create: (_) => _FakeTap()),
      ],
      child: MaterialApp(home: SubscriptionPlanDetailsPage(plan: plan)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('the plan is printed as sentences, not as column values', (
    tester,
  ) async {
    _setSurface(tester);
    final repository = _FakeRepository();

    await _pumpPage(tester, repository, _plan);
    await tester.pumpAndSettle();

    // The name is printed twice: as the bar the customer is standing under and
    // as the heading that wraps when the name is too long for the bar.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Monthly plan'),
      ),
      findsOneWidget,
    );
    expect(find.text('Monthly plan'), findsNWidgets(2));
    expect(find.text('Sixty cups a month'), findsOneWidget);
    expect(
      find.text('${S.priceLabel}: ${Formatters.price(149, 'SAR')}'),
      findsOneWidget,
    );
    expect(find.text('${S.durationLabel}: ${S.daysCount(30)}'), findsOneWidget);
    expect(find.text('${S.cupsPerCycle}: ${S.cupsCount(60)}'), findsOneWidget);
    expect(
      find.text('${S.renewalLabel}: ${S.renewalAutomatic}'),
      findsOneWidget,
    );
    expect(find.text('${S.productsLabel}: ${S.allProducts}'), findsOneWidget);
    // The words the columns hold are never shown to the customer.
    expect(find.text('auto'), findsNothing);
    expect(find.text('all'), findsNothing);
    // A plan that hands out no credit does not offer a line about it.
    expect(find.text(S.extraCredit), findsNothing);
  });

  testWidgets('a plan covering every product reads no product list', (
    tester,
  ) async {
    _setSurface(tester);
    final repository = _FakeRepository();

    await _pumpPage(tester, repository, _plan);
    await tester.pumpAndSettle();

    expect(repository.productsCalls, 0);
    expect(find.text(S.includedProducts), findsNothing);
  });

  testWidgets('a plan of selected products names them, with their price', (
    tester,
  ) async {
    _setSurface(tester);
    final repository = _FakeRepository(
      productsToReturn: const [
        SubscriptionPlanProduct(
          id: 'p1',
          nameAr: 'لاتيه',
          nameEn: 'Latte',
          price: 18,
          imageUrl: 'assets/images/product.png',
        ),
      ],
    );

    await _pumpPage(tester, repository, _selectedProductsPlan);
    await tester.pumpAndSettle();

    expect(repository.lastProductsPlanId, 'plan-2');
    expect(find.text(S.includedProducts), findsOneWidget);
    expect(find.text('Latte'), findsOneWidget);
    expect(find.text(Formatters.price(18, 'SAR')), findsOneWidget);
    // The picture is the shared loader, not a second copy of it.
    expect(find.byType(DbImage), findsOneWidget);
    // This one does hand out credit, so it is stated.
    expect(
      find.text('${S.extraCredit}: ${Formatters.amount(25)}'),
      findsOneWidget,
    );
  });

  testWidgets('a product list that failed says so and keeps the plan', (
    tester,
  ) async {
    _setSurface(tester);
    final repository = _FakeRepository()..productsError = StateError('offline');

    await _pumpPage(tester, repository, _selectedProductsPlan);
    await tester.pumpAndSettle();

    expect(find.text(S.couldNotLoadPlanProducts), findsOneWidget);
    expect(find.text(S.retry), findsOneWidget);
    expect(
      find.textContaining('offline'),
      findsNothing,
      reason: 'the backend message is never shown to the customer',
    );
    // The plan the customer is paying for is still on screen.
    expect(find.text('Latte plan'), findsNWidgets(2));

    repository.productsError = null;
    await tester.tap(find.text(S.retry));
    await tester.pumpAndSettle();

    expect(repository.productsCalls, 2);
    expect(find.text(S.couldNotLoadPlanProducts), findsNothing);
    expect(find.text(S.noProductsYet), findsOneWidget);
  });

  testWidgets('the payment is opened for the subscription just created', (
    tester,
  ) async {
    _setSurface(tester);
    final repository = _FakeRepository();

    await _pumpPage(tester, repository, _plan);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, S.subscribeNow));
    // The card form animates while it waits for the hosted session, so the
    // route is stepped by hand instead of settled.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final page = tester.widget<CardPaymentPage>(find.byType(CardPaymentPage));
    expect(page.subscriptionId, 'sub-1');
    expect(page.amount, 149);
    expect(page.currency, 'SAR');

    Navigator.of(tester.element(find.byType(CardPaymentPage))).pop();
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('a refused subscribe opens no payment', (tester) async {
    _setSurface(tester);
    final repository = _FakeRepository()
      ..subscribeError = StateError('permission denied for subscribe');

    await _pumpPage(tester, repository, _plan);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, S.subscribeNow));
    await tester.pump();
    await tester.pump();

    expect(find.text(S.couldNotStartSubscription), findsOneWidget);
    expect(find.byType(CardPaymentPage), findsNothing);
    expect(
      find.textContaining('permission denied'),
      findsNothing,
      reason: 'the backend message is never shown to the customer',
    );
  });

  testWidgets('the second tap while the first is unpaid writes nothing', (
    tester,
  ) async {
    _setSurface(tester);
    final repository = _FakeRepository()..subscribeGate = Completer();

    await _pumpPage(tester, repository, _plan);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, S.subscribeNow));
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, S.subscribeNow),
    );
    expect(
      button.onPressed,
      isNull,
      reason: 'the button cannot say what a second tap would do',
    );

    await tester.tap(find.widgetWithText(FilledButton, S.subscribeNow));
    await tester.pump();

    expect(repository.subscribeCalls, 1);
  });
}

/// The hosted checkout is only reached through [CardPaymentPage], which needs a
/// payment repository to exist; no charge is made by these tests.
class _FakeTap implements TapPaymentRepository {
  @override
  Future<TapChargeResult> createCharge({
    required String orderId,
    required String idempotencyKey,
    bool saveCard = false,
    String? savedCardId,
    String? sourceToken,
  }) async => const TapChargeResult(
    chargeId: 'ch_1',
    status: 'INITIATED',
    transactionUrl: 'https://tap.company/3ds',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
