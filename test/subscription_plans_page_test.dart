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
import 'package:new_coffee/features/subscriptions/presentation/manager/subscription/subscription_cubit.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_plan_details_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_plans_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/widgets/subscription_plan_card.dart';

/// The plans page is the customer's first look at a paid product, so its two
/// failure modes matter more than its happy path: a guest must not be sent a
/// request the server refuses, and a real failure must not print the raw
/// backend message.
class _FakeRepository implements SubscriptionRepository {
  _FakeRepository({
    this.plansToReturn = const [],
    this.failPlans = false,
    this.subscriptionToReturn,
  });

  List<SubscriptionPlan> plansToReturn;
  bool failPlans;

  /// The subscription the customer already had, when the page is opened.
  CustomerSubscription? subscriptionToReturn;

  /// The branches each plan read was asked for, in order.
  final List<String?> plansReadFor = [];

  int plansCalls = 0;
  int subscribeCalls = 0;

  /// Holds a subscribe open, so a second tap can be made while the first one
  /// is still in flight.
  Completer<CustomerSubscription>? subscribeGate;

  /// Why the write refuses, so the page can be proved to open no payment for a
  /// subscription it did not create.
  Object? subscribeError;

  @override
  Future<List<SubscriptionPlan>> plans({String? branchId}) async {
    plansCalls++;
    plansReadFor.add(branchId);
    if (failPlans) {
      throw StateError('permission denied for function list_plans');
    }
    return plansToReturn;
  }

  @override
  Future<CustomerSubscription?> mySubscription() async => subscriptionToReturn;

  @override
  Future<List<SubscriptionUsage>> usageHistory({
    String? subscriptionId,
  }) async => const [];

  @override
  Future<List<SubscriptionPlanProduct>> planProducts(String planId) async =>
      const [];

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

class _FakeBranchRepository implements BranchRepository {
  _FakeBranchRepository(this.branches);

  final List<Branch> branches;

  @override
  Future<List<Branch>> activeBranches() async => branches;
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

Branch _branch(String id, String name) =>
    Branch(id: id, code: id, nameAr: name, nameEn: name);

const _dailyPlan = SubscriptionPlan(
  id: 'p1',
  code: 'daily',
  nameAr: 'باقة يومية',
  nameEn: 'Daily plan',
  price: 99,
);

void _setPhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<BranchCubit> _pumpPage(
  WidgetTester tester,
  _FakeRepository repo, {
  List<Branch> branches = const [],
}) async {
  final branch = BranchCubit(repository: _FakeBranchRepository(branches));
  addTearDown(branch.close);
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SubscriptionRepository>.value(value: repo),
        RepositoryProvider<TapPaymentRepository>.value(value: _FakeTap()),
      ],
      child: MaterialApp(
        routes: {
          SubscriptionPlanDetailsPage.routeName: (context) {
            final plan =
                ModalRoute.of(context)!.settings.arguments as SubscriptionPlan;
            return SubscriptionPlanDetailsPage(plan: plan);
          },
        },
        home: BlocProvider.value(
          value: branch,
          child: const SubscriptionPlansPage(),
        ),
      ),
    ),
  );
  return branch;
}

/// The cubit the page made for itself, read from under its own provider.
SubscriptionCubit _cubitOf(WidgetTester tester) =>
    BlocProvider.of<SubscriptionCubit>(
      tester.element(find.byType(AppBar).first),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  tearDown(() => SupabaseService.debugReset());

  testWidgets('a signed-out customer is asked to sign in, not shown an error', (
    tester,
  ) async {
    _setPhoneSurface(tester);
    SupabaseService.debugSetSignedIn(false);
    final repository = _FakeRepository();

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text(S.signInRequired), findsOneWidget);
    expect(
      repository.plansCalls,
      0,
      reason: 'the server refuses an anonymous plan read, so none is sent',
    );
  });

  testWidgets('the plans of a signed-in customer are listed', (tester) async {
    _setPhoneSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    final repository = _FakeRepository(plansToReturn: const [_dailyPlan]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.plansCalls, 1);
    expect(find.text('Daily plan'), findsOneWidget);
  });

  testWidgets('a failed plan read says so in the customer\'s words', (
    tester,
  ) async {
    _setPhoneSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    final repository = _FakeRepository(failPlans: true);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text(S.couldNotLoadPlans), findsOneWidget);
    expect(find.text(S.retry), findsOneWidget);
    expect(
      find.textContaining('permission denied'),
      findsNothing,
      reason: 'the backend message is never shown to the customer',
    );
  });

  testWidgets('a re-read keeps the plans the customer is looking at', (
    tester,
  ) async {
    _setPhoneSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    final repository = _FakeRepository(plansToReturn: const [_dailyPlan]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    final reload = _cubitOf(tester).load();
    await tester.pump();

    expect(
      find.byType(SubscriptionPlanCard),
      findsOneWidget,
      reason: 'the grid is the answer the customer is standing on',
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await reload;
    await tester.pump();
  });

  testWidgets('choosing another branch re-reads the plans sold there', (
    tester,
  ) async {
    _setPhoneSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    final repository = _FakeRepository(plansToReturn: const [_dailyPlan]);
    final branch = await _pumpPage(
      tester,
      repository,
      branches: [_branch('b1', 'First'), _branch('b2', 'Second')],
    );
    await tester.pumpAndSettle();

    expect(repository.plansReadFor, [null]);

    await branch.select(_branch('b1', 'First'));
    await tester.pumpAndSettle();
    expect(repository.plansReadFor, [null, 'b1']);

    // The same branch is the same answer, so a rebuild asks for nothing.
    await branch.select(_branch('b1', 'First'));
    await tester.pumpAndSettle();
    expect(repository.plansReadFor, [null, 'b1']);

    await branch.select(_branch('b2', 'Second'));
    await tester.pumpAndSettle();
    expect(repository.plansReadFor, [null, 'b1', 'b2']);
  });

  testWidgets('the first tap holds the whole grid until it is answered', (
    tester,
  ) async {
    _setPhoneSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    final gate = Completer<CustomerSubscription>();
    final repository = _FakeRepository(plansToReturn: const [_dailyPlan])
      ..subscribeGate = gate;

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, S.subscribeNow));
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, S.subscribeNow),
          )
          .onPressed,
      isNull,
      reason: 'a second tap cannot know whether the first subscribed',
    );
    expect(
      tester
          .widget<SubscriptionPlanCard>(find.byType(SubscriptionPlanCard))
          .busy,
      isTrue,
    );
    expect(repository.subscribeCalls, 1);
  });

  testWidgets('a refused subscribe opens no payment', (tester) async {
    _setPhoneSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    final repository = _FakeRepository(
      plansToReturn: const [_dailyPlan],
      subscriptionToReturn: const CustomerSubscription(
        id: 'sub-old',
        planId: 'plan-old',
      ),
    )..subscribeError = StateError('permission denied for subscribe');

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, S.subscribeNow));
    await tester.pump();

    expect(find.text(S.couldNotStartSubscription), findsOneWidget);
    expect(
      find.byType(CardPaymentPage),
      findsNothing,
      reason:
          'the customer already holds a subscription; paying for it at this '
          'plan price would charge the wrong row',
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the payment is opened for the subscription just created', (
    tester,
  ) async {
    _setPhoneSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    final repository = _FakeRepository(plansToReturn: const [_dailyPlan]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, S.subscribeNow));
    // The card form animates while it waits for the hosted session, so the
    // route is stepped by hand instead of settled.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final page = tester.widget<CardPaymentPage>(find.byType(CardPaymentPage));
    expect(page.subscriptionId, 'sub-1');
    expect(page.amount, 99);
    expect(page.currency, 'SAR');

    Navigator.of(tester.element(find.byType(CardPaymentPage))).pop();
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('a plan card opens its own details', (tester) async {
    _setPhoneSurface(tester);
    SupabaseService.debugSetSignedIn(true);
    final repository = _FakeRepository(plansToReturn: const [_dailyPlan]);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SubscriptionPlanCard));
    await tester.pumpAndSettle();

    expect(find.byType(SubscriptionPlanDetailsPage), findsOneWidget);
  });
}
