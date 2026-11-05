import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/branch/data/model/branch_model.dart';
import 'package:new_coffee/features/branch/data/repositories/branch_repository.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/payment/data/repositories/tap_payment_repository.dart';
import 'package:new_coffee/features/payment/presentation/views/card_payment_page.dart';
import 'package:new_coffee/features/subscriptions/data/model/customer_subscription.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan_product.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_usage.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_details_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_plans_page.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

/// My subscription is the page a customer reads before spending a cup, so a
/// side failure that throws the whole page away is the defect this file is
/// written for: the facts stay on screen and each action answers on its own.
class _FakeRepository implements SubscriptionRepository {
  _FakeRepository({this.plansToReturn = const [], this.subscriptionToReturn});

  List<SubscriptionPlan> plansToReturn;
  CustomerSubscription? subscriptionToReturn;

  Object? plansError;
  Object? renewError;
  Object? cancelError;
  Object? setAutoRenewError;
  Object? qrError;

  String qrTokenToReturn = 'qr-1';
  int plansCalls = 0;
  int renewCalls = 0;
  int cancelCalls = 0;
  int autoRenewCalls = 0;
  int qrCalls = 0;

  /// The subscription the renewal created, so the page can be proved to pay
  /// that row and not the one it was already showing.
  CustomerSubscription renewedToReturn = const CustomerSubscription(
    id: 'renewed-1',
    planId: 'plan-1',
  );

  /// Holds a write open so the buttons can be looked at while it is in flight.
  Completer<CustomerSubscription>? renewGate;

  List<SubscriptionUsage> usageToReturn = const [];
  Object? usageError;

  @override
  Future<List<SubscriptionPlan>> plans({String? branchId}) async {
    plansCalls++;
    final error = plansError;
    if (error != null) throw error;
    return plansToReturn;
  }

  @override
  Future<CustomerSubscription?> mySubscription() async => subscriptionToReturn;

  @override
  Future<List<SubscriptionUsage>> usageHistory({String? subscriptionId}) async {
    final error = usageError;
    if (error != null) throw error;
    return usageToReturn;
  }

  @override
  Future<List<SubscriptionPlanProduct>> planProducts(String planId) async =>
      const [];

  @override
  Future<CustomerSubscription> renew({
    required String subscriptionId,
    required String paymentReference,
    required String idempotencyKey,
  }) async {
    renewCalls++;
    final gate = renewGate;
    if (gate != null) return gate.future;
    final error = renewError;
    if (error != null) throw error;
    return subscriptionToReturn = renewedToReturn;
  }

  @override
  Future<void> cancel({required String subscriptionId}) async {
    cancelCalls++;
    final error = cancelError;
    if (error != null) throw error;
    subscriptionToReturn = null;
  }

  @override
  Future<void> setAutoRenew({
    required String subscriptionId,
    required bool enabled,
  }) async {
    autoRenewCalls++;
    final error = setAutoRenewError;
    if (error != null) throw error;
  }

  @override
  Future<String> generateQrToken({required String subscriptionId}) async {
    qrCalls++;
    final error = qrError;
    if (error != null) throw error;
    return qrTokenToReturn;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeBranchRepository implements BranchRepository {
  @override
  Future<List<Branch>> activeBranches() async => const [];
}

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
  Future<TapChargeResult> createSubscriptionCharge({
    required String subscriptionId,
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
  Future<TapVerificationResult> verifyCharge(String chargeId) async =>
      TapVerificationResult(
        chargeId: chargeId,
        status: 'CAPTURED',
        verified: true,
        orderPaymentStatus: 'paid',
      );
}

final _start = DateTime(2026, 10, 1);
final _end = DateTime(2026, 12, 1);

const _plan = SubscriptionPlan(
  id: 'plan-1',
  code: 'monthly',
  nameAr: 'باقة شهرية',
  nameEn: 'Monthly plan',
  price: 149,
  cupsPerCycle: 30,
);

CustomerSubscription _subscription({
  String status = 'active',
  int cupsEntitled = 10,
  int cupsUsed = 3,
}) => CustomerSubscription(
  id: 'sub-old',
  planId: 'plan-1',
  planNameAr: 'باقة شهرية',
  planNameEn: 'Monthly plan',
  status: status,
  startsAt: _start,
  endsAt: _end,
  cupsEntitled: cupsEntitled,
  cupsUsed: cupsUsed,
);

void _setSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1400) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(WidgetTester tester, _FakeRepository repo) async {
  final branch = BranchCubit(repository: _FakeBranchRepository());
  addTearDown(branch.close);
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SubscriptionRepository>.value(value: repo),
        RepositoryProvider<TapPaymentRepository>.value(value: _FakeTap()),
      ],
      child: MaterialApp(
        routes: {
          SubscriptionPlansPage.routeName: (context) =>
              const Scaffold(body: Text('plans page')),
        },
        home: BlocProvider.value(
          value: branch,
          child: const SubscriptionDetailsPage(),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  tearDown(() => SupabaseService.debugReset());

  testWidgets('a guest is asked to sign in and no read is made', (
    tester,
  ) async {
    _setSurface(tester);
    SupabaseService.debugSetSignedIn(false);
    final repository = _FakeRepository();

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text(S.signInRequired), findsOneWidget);
    expect(repository.plansCalls, 0);
  });

  testWidgets('a customer without a subscription is sent to the plans', (
    tester,
  ) async {
    _setSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    await _pumpPage(tester, _FakeRepository());
    await tester.pumpAndSettle();

    expect(find.text(S.noSubscriptionYet), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, S.browsePlans));
    await tester.pumpAndSettle();
    expect(find.text('plans page'), findsOneWidget);
  });

  testWidgets('a page that has never been read says so and offers a retry', (
    tester,
  ) async {
    _setSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    final repository = _FakeRepository()..plansError = StateError('offline');

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text(S.couldNotLoadSubscription), findsOneWidget);
    expect(
      find.textContaining('offline'),
      findsNothing,
      reason: 'the backend message is never shown to the customer',
    );

    repository.plansError = null;
    await tester.tap(find.widgetWithText(FilledButton, S.retry));
    await tester.pumpAndSettle();

    expect(repository.plansCalls, 2);
    expect(find.text(S.noSubscriptionYet), findsOneWidget);
  });

  testWidgets('the subscription is read as facts, in the customer language', (
    tester,
  ) async {
    _setSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    final repository =
        _FakeRepository(
            plansToReturn: const [_plan],
            subscriptionToReturn: _subscription(),
          )
          ..usageToReturn = [
            SubscriptionUsage(
              id: 'u1',
              subscriptionId: 'sub-old',
              branchId: 'b1',
              quantity: 2,
              createdAt: null,
            ),
            SubscriptionUsage(
              id: 'u2',
              subscriptionId: 'sub-old',
              branchId: 'b1',
              method: 'cashier',
              createdAt: _start,
            ),
          ];

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Monthly plan'), findsOneWidget);
    // Each fact is one "label: value" line, the way the customer reads it.
    expect(
      find.text('${S.subscriptionStatus}: ${S.subscriptionActive}'),
      findsOneWidget,
    );
    // Both dates are printed once as a labelled fact of the subscription, and
    // the history row that spent a cup on the same day prints its bare date.
    expect(
      find.text('${S.subscriptionStart}: ${Formatters.date(_start)}'),
      findsOneWidget,
    );
    expect(
      find.text('${S.subscriptionEnd}: ${Formatters.date(_end)}'),
      findsOneWidget,
    );
    expect(find.text(Formatters.date(_start)), findsOneWidget);
    expect(find.text('${S.availableCups}: 7'), findsOneWidget);

    // A history row is a cup count and a method, never a bare number and never
    // the column word.
    expect(find.text(S.cupsCount(2)), findsOneWidget);
    expect(find.text(S.usageByCashier), findsOneWidget);
    expect(find.text(S.usageByQr), findsOneWidget);
  });

  testWidgets('a pass that could not be made keeps the page on screen', (
    tester,
  ) async {
    _setSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    final repository = _FakeRepository(
      plansToReturn: const [_plan],
      subscriptionToReturn: _subscription(),
    )..qrError = StateError('offline');

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, S.showQrCode));
    await tester.pump();

    expect(find.text(S.couldNotShowQr), findsOneWidget);
    expect(
      find.text('Monthly plan'),
      findsOneWidget,
      reason: 'the pass is one button on a page full of facts',
    );
    expect(find.text(S.couldNotLoadSubscription), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('an auto-renew the server refused is its own line', (
    tester,
  ) async {
    _setSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    final repository = _FakeRepository(
      plansToReturn: const [_plan],
      subscriptionToReturn: _subscription(),
    )..setAutoRenewError = StateError('offline');

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    expect(find.text(S.couldNotSaveAutoRenew), findsOneWidget);
    expect(find.text('Monthly plan'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      false,
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a refresh that failed leaves the facts with a notice', (
    tester,
  ) async {
    _setSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    final repository = _FakeRepository(
      plansToReturn: const [_plan],
      subscriptionToReturn: _subscription(status: 'pending_payment'),
    );

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('Monthly plan'), findsOneWidget);

    repository.plansError = StateError('offline');
    await tester.tap(find.widgetWithText(FilledButton, S.checkPaymentStatus));
    await tester.pumpAndSettle();

    expect(find.text('Monthly plan'), findsOneWidget);
    expect(find.text(S.subscriptionOutdated), findsOneWidget);
    expect(find.text(S.couldNotLoadSubscription), findsNothing);

    repository.plansError = null;
    await tester.tap(find.widgetWithText(TextButton, S.retry).first);
    await tester.pumpAndSettle();
    expect(find.text(S.subscriptionOutdated), findsNothing);
  });

  testWidgets('renewal opens the payment for the row the renewal created', (
    tester,
  ) async {
    _setSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    final repository = _FakeRepository(
      plansToReturn: const [_plan],
      subscriptionToReturn: _subscription(),
    );

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, S.renew));
    // The card form animates while it waits for the hosted session.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(repository.renewCalls, 1);
    final page = tester.widget<CardPaymentPage>(find.byType(CardPaymentPage));
    expect(
      page.subscriptionId,
      'renewed-1',
      reason: 'the old row is a cycle that is already spent',
    );
    expect(page.amount, 149);

    Navigator.of(tester.element(find.byType(CardPaymentPage))).pop();
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('a renewal whose plan is not priced opens no payment', (
    tester,
  ) async {
    _setSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    final repository =
        _FakeRepository(
            plansToReturn: const [_plan],
            subscriptionToReturn: _subscription(),
          )
          ..renewedToReturn = const CustomerSubscription(
            id: 'renewed-9',
            planId: 'plan-gone',
          );

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, S.renew));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text(S.couldNotPriceRenewal), findsOneWidget);
    expect(
      find.byType(CardPaymentPage),
      findsNothing,
      reason: 'an unknown plan price is never charged as a free renewal',
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a renewal in flight disables every write', (tester) async {
    _setSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    final gate = Completer<CustomerSubscription>();
    final repository = _FakeRepository(
      plansToReturn: const [_plan],
      subscriptionToReturn: _subscription(),
    )..renewGate = gate;

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, S.renew));
    await tester.pump();

    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, S.renew))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, S.cancel))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
    expect(repository.renewCalls, 1);
  });

  testWidgets('a cancelled subscription is gone from the page', (tester) async {
    _setSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    final repository = _FakeRepository(
      plansToReturn: const [_plan],
      subscriptionToReturn: _subscription(),
    );

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, S.cancel));
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, 1);
    expect(find.text(S.noSubscriptionYet), findsOneWidget);
    expect(find.text('Monthly plan'), findsNothing);
  });
}
