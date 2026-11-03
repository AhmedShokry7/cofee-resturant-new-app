import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/subscriptions/data/model/customer_subscription.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan_product.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_usage.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_plans_page.dart';

/// The plans page is the customer's first look at a paid product, so its two
/// failure modes matter more than its happy path: a guest must not be sent a
/// request the server refuses, and a real failure must not print the raw
/// backend message.
class _FakeRepository implements SubscriptionRepository {
  _FakeRepository({this.plansToReturn = const [], this.failPlans = false});

  List<SubscriptionPlan> plansToReturn;
  bool failPlans;

  int plansCalls = 0;

  @override
  Future<List<SubscriptionPlan>> plans({String? branchId}) async {
    plansCalls++;
    if (failPlans) {
      throw StateError('permission denied for function list_plans');
    }
    return plansToReturn;
  }

  @override
  Future<CustomerSubscription?> mySubscription() async => null;

  @override
  Future<List<SubscriptionUsage>> usageHistory({
    String? subscriptionId,
  }) async => const [];

  @override
  Future<List<SubscriptionPlanProduct>> planProducts(String planId) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void _setPhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 690) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(WidgetTester tester, SubscriptionRepository repo) {
  return tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SubscriptionRepository>.value(value: repo),
      ],
      child: MaterialApp(home: const SubscriptionPlansPage()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

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
    final repository = _FakeRepository(
      plansToReturn: const [
        SubscriptionPlan(
          id: 'p1',
          code: 'daily',
          nameAr: 'باقة يومية',
          nameEn: 'Daily plan',
          price: 99,
        ),
      ],
    );

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
}
