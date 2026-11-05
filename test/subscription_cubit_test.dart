import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/subscriptions/data/model/customer_subscription.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan_product.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_usage.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/subscriptions/presentation/manager/subscription/subscription_cubit.dart';

class _FakeRepository implements SubscriptionRepository {
  List<SubscriptionPlan> plansToReturn = const [];
  CustomerSubscription? subscription;
  List<SubscriptionUsage> usageToReturn = const [];
  Object? plansError;
  Object? usageError;

  final List<String?> usageReadFor = [];
  final List<String?> plansReadFor = [];
  final List<String> subscribeKeys = [];

  /// The history held for one subscription, and the gate that can hold its
  /// read open so a slow answer can be compared with a newer one.
  final Map<String, List<SubscriptionUsage>> usageBySubscription = {};
  final Map<String, Completer<void>> usageGates = {};

  /// Holds a write open so a second tap can be made while the first is still
  /// in flight.
  Completer<void>? writeGate;

  int _subscribeCalls = 0;
  int _renewCalls = 0;
  int cancelCalls = 0;
  int autoRenewCalls = 0;
  int qrCalls = 0;

  Object? subscribeError;
  Object? renewError;
  Object? cancelError;
  Object? setAutoRenewError;
  Object? qrError;
  String qrTokenToReturn = 'qr-1';

  /// Fails the first subscribe attempt only, so a retry can be compared with
  /// the attempt that came before it.
  Object? firstSubscribeError;

  /// Lets a test hold a write open and drive the two calls apart.
  Future<void> _waitForWrite() async {
    final gate = writeGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<List<SubscriptionPlan>> plans({String? branchId}) async {
    plansReadFor.add(branchId);
    final error = plansError;
    if (error != null) throw error;
    return plansToReturn;
  }

  @override
  Future<CustomerSubscription?> mySubscription() async => subscription;

  List<SubscriptionPlanProduct> planProductsToReturn = const [];
  Object? planProductsError;

  @override
  Future<List<SubscriptionPlanProduct>> planProducts(String planId) async {
    final error = planProductsError;
    if (error != null) throw error;
    return planProductsToReturn;
  }

  @override
  Future<List<SubscriptionUsage>> usageHistory({String? subscriptionId}) async {
    usageReadFor.add(subscriptionId);
    await usageGates[subscriptionId]?.future;
    final error = usageError;
    if (error != null) throw error;
    return usageBySubscription[subscriptionId ?? ''] ?? usageToReturn;
  }

  @override
  Future<CustomerSubscription> subscribe({
    required String planId,
    required String idempotencyKey,
  }) async {
    subscribeKeys.add(idempotencyKey);
    _subscribeCalls++;
    await _waitForWrite();
    if (_subscribeCalls == 1 && firstSubscribeError != null) {
      throw firstSubscribeError!;
    }
    final error = subscribeError;
    if (error != null) throw error;
    return subscription = CustomerSubscription(
      id: 'sub-$_subscribeCalls',
      planId: planId,
    );
  }

  @override
  Future<CustomerSubscription> renew({
    required String subscriptionId,
    required String paymentReference,
    required String idempotencyKey,
  }) async {
    _renewCalls++;
    await _waitForWrite();
    final error = renewError;
    if (error != null) throw error;
    return subscription = CustomerSubscription(
      id: 'renewed-$_renewCalls',
      planId: subscription?.planId ?? 'plan-1',
    );
  }

  @override
  Future<void> cancel({required String subscriptionId}) async {
    cancelCalls++;
    final error = cancelError;
    if (error != null) throw error;
    subscription = null;
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

SubscriptionPlan _plan({String id = 'plan-1'}) {
  return SubscriptionPlan(
    id: id,
    code: 'daily',
    nameAr: 'باقة يومية',
    nameEn: 'Daily plan',
    price: 99,
  );
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('SubscriptionCubit', () {
    test('load reads the history of the subscription it found', () async {
      final repository = _FakeRepository()
        ..plansToReturn = [_plan()]
        ..subscription = const CustomerSubscription(
          id: 'sub-1',
          planId: 'plan-1',
        )
        ..usageToReturn = const [
          SubscriptionUsage(id: 'u1', subscriptionId: 'sub-1', branchId: 'b1'),
        ];

      final cubit = SubscriptionCubit(repository: repository);
      await cubit.load();

      expect(cubit.state.subscription?.id, 'sub-1');
      expect(cubit.state.usage?.length, 1);
      expect(repository.usageReadFor, ['sub-1']);
      await cubit.close();
    });

    test(
      'a usage row is labelled with the product it spent, not the method',
      () async {
        final repository = _FakeRepository()
          ..plansToReturn = [_plan()]
          ..subscription = const CustomerSubscription(
            id: 'sub-1',
            planId: 'plan-1',
          )
          ..planProductsToReturn = const [
            SubscriptionPlanProduct(id: 'p1', nameAr: 'لاتيه', nameEn: 'Latte'),
          ]
          ..usageToReturn = const [
            SubscriptionUsage(
              id: 'u1',
              subscriptionId: 'sub-1',
              branchId: 'b1',
              productId: 'p1',
            ),
          ];

        final cubit = SubscriptionCubit(repository: repository);
        await cubit.load();

        expect(cubit.state.usage?.single.productName, 'Latte');
        await cubit.close();
      },
    );

    test(
      'a failed product read still shows the history that arrived',
      () async {
        final repository = _FakeRepository()
          ..plansToReturn = [_plan()]
          ..subscription = const CustomerSubscription(
            id: 'sub-1',
            planId: 'plan-1',
          )
          ..planProductsError = StateError('offline')
          ..usageToReturn = const [
            SubscriptionUsage(
              id: 'u1',
              subscriptionId: 'sub-1',
              branchId: 'b1',
              productId: 'p1',
            ),
          ];

        final cubit = SubscriptionCubit(repository: repository);
        await cubit.load();

        expect(cubit.state.usage?.single.productId, 'p1');
        expect(cubit.state.usage?.single.productName, isNull);
        expect(cubit.state.usageError, isNull);
        await cubit.close();
      },
    );

    test('a failed history read keeps the subscription on screen', () async {
      final repository = _FakeRepository()
        ..subscription = const CustomerSubscription(
          id: 'sub-1',
          planId: 'plan-1',
        )
        ..usageError = StateError('offline');

      final cubit = SubscriptionCubit(repository: repository);
      await cubit.load();

      expect(cubit.state.subscription?.id, 'sub-1');
      expect(cubit.state.usage, isNull);
      expect(cubit.state.usageError, isNotNull);
      expect(cubit.state.loadError, isNull);
      await cubit.close();
    });

    test(
      'a failed load stops the spinner instead of spinning forever',
      () async {
        final repository = _FakeRepository()
          ..plansError = StateError('offline');

        final cubit = SubscriptionCubit(repository: repository);
        await cubit.load();

        expect(cubit.state.loading, isFalse);
        expect(cubit.state.loadError, isNotNull);
        await cubit.close();
      },
    );

    test(
      'a retry of a failed subscribe sends the same idempotency key',
      () async {
        final repository = _FakeRepository()
          ..firstSubscribeError = StateError(
            'timeout after the row was written',
          );

        final cubit = SubscriptionCubit(repository: repository);
        await cubit.subscribe(_plan());
        await cubit.subscribe(_plan());

        expect(repository.subscribeKeys, hasLength(2));
        expect(
          repository.subscribeKeys.first,
          repository.subscribeKeys.last,
          reason: 'one tap must not become two subscriptions',
        );
        await cubit.close();
      },
    );

    test('a second intent gets its own idempotency key', () async {
      final repository = _FakeRepository();

      final cubit = SubscriptionCubit(repository: repository);
      await cubit.subscribe(_plan());
      await cubit.subscribe(_plan());

      expect(
        repository.subscribeKeys.first,
        isNot(repository.subscribeKeys.last),
      );
      await cubit.close();
    });

    test('the renewal plan is the plan the subscription belongs to', () async {
      final cubit = SubscriptionCubit(
        repository: _FakeRepository()
          ..plansToReturn = [_plan(id: 'plan-1'), _plan(id: 'plan-2')]
          ..subscription = const CustomerSubscription(
            id: 'sub-1',
            planId: 'plan-2',
          ),
      );
      await cubit.load();

      expect(cubit.renewalPlan?.id, 'plan-2');
      await cubit.close();
    });

    test(
      'subscribe answers with the row it created, not the one on screen',
      () async {
        final repository = _FakeRepository()
          ..plansToReturn = [_plan()]
          ..subscription = const CustomerSubscription(
            id: 'sub-old',
            planId: 'plan-0',
          );

        final cubit = SubscriptionCubit(repository: repository);
        await cubit.load();

        final created = await cubit.subscribe(_plan(id: 'plan-9'));

        expect(created?.id, 'sub-1');
        expect(created?.planId, 'plan-9');
        expect(cubit.state.subscription?.id, 'sub-1');
        await cubit.close();
      },
    );

    test(
      'a second tap while a subscribe is in flight writes nothing',
      () async {
        final gate = Completer<void>();
        final repository = _FakeRepository()..writeGate = gate;
        final cubit = SubscriptionCubit(repository: repository);

        final first = cubit.subscribe(_plan());
        expect(await cubit.subscribe(_plan()), isNull);

        gate.complete();
        expect((await first)?.id, 'sub-1');
        expect(repository.subscribeKeys, hasLength(1));
        await cubit.close();
      },
    );

    test('renew answers with the subscription it created', () async {
      final repository = _FakeRepository()
        ..plansToReturn = [_plan()]
        ..subscription = const CustomerSubscription(
          id: 'sub-1',
          planId: 'plan-1',
        );

      final cubit = SubscriptionCubit(repository: repository);
      await cubit.load();

      final renewed = await cubit.renew();

      expect(renewed?.id, 'renewed-1');
      expect(cubit.renewalPlan?.id, 'plan-1');
      await cubit.close();
    });

    test('a renewal with no subscription on screen writes nothing', () async {
      final repository = _FakeRepository();
      final cubit = SubscriptionCubit(repository: repository);
      await cubit.load();

      expect(await cubit.renew(), isNull);
      expect(cubit.state.isMutating, isFalse);
      await cubit.close();
    });

    test('a refused write leaves the subscription on screen', () async {
      final repository = _FakeRepository()
        ..plansToReturn = [_plan()]
        ..subscription = const CustomerSubscription(
          id: 'sub-1',
          planId: 'plan-1',
        )
        ..cancelError = StateError('offline');

      final cubit = SubscriptionCubit(repository: repository);
      await cubit.load();

      expect(await cubit.cancel(), isFalse);

      expect(cubit.state.subscription?.id, 'sub-1');
      expect(cubit.state.actionError, isNotNull);
      expect(cubit.state.loadError, isNull);
      expect(cubit.state.isMutating, isFalse);
      await cubit.close();
    });

    test('auto-renew refused is its own line, not a blank page', () async {
      final repository = _FakeRepository()
        ..plansToReturn = [_plan()]
        ..subscription = const CustomerSubscription(
          id: 'sub-1',
          planId: 'plan-1',
        )
        ..setAutoRenewError = StateError('offline');

      final cubit = SubscriptionCubit(repository: repository);
      await cubit.load();

      expect(await cubit.setAutoRenew(true), isFalse);

      expect(cubit.state.subscription?.autoRenew, isFalse);
      expect(cubit.state.actionError, isNotNull);
      expect(cubit.state.loadError, isNull);
      await cubit.close();
    });

    test('a pass that could not be made is not left on screen', () async {
      final repository = _FakeRepository()
        ..subscription = const CustomerSubscription(
          id: 'sub-1',
          planId: 'plan-1',
        );
      final cubit = SubscriptionCubit(repository: repository);
      await cubit.load();

      expect(await cubit.showQr(), isTrue);
      expect(cubit.state.qrToken, 'qr-1');

      repository
        ..qrError = StateError('offline')
        ..qrTokenToReturn = 'qr-2';
      expect(await cubit.showQr(), isFalse);

      expect(cubit.state.qrToken, isNull);
      expect(cubit.state.qrError, isNotNull);
      expect(cubit.state.subscription?.id, 'sub-1');
      expect(cubit.state.loadError, isNull);
      await cubit.close();
    });

    test('a re-read drops the pass that was on screen', () async {
      final repository = _FakeRepository()
        ..subscription = const CustomerSubscription(
          id: 'sub-1',
          planId: 'plan-1',
        );
      final cubit = SubscriptionCubit(repository: repository);
      await cubit.load();
      await cubit.showQr();

      await cubit.load();

      expect(cubit.state.qrToken, isNull);
      await cubit.close();
    });

    test('cancelling drops the pass with the subscription', () async {
      final repository = _FakeRepository()
        ..subscription = const CustomerSubscription(
          id: 'sub-1',
          planId: 'plan-1',
        );
      final cubit = SubscriptionCubit(repository: repository);
      await cubit.load();
      await cubit.showQr();

      expect(await cubit.cancel(), isTrue);

      expect(cubit.state.subscription, isNull);
      expect(cubit.state.qrToken, isNull);
      await cubit.close();
    });

    test('a branch change re-reads the plans of that branch', () async {
      final repository = _FakeRepository()..plansToReturn = [_plan()];
      final cubit = SubscriptionCubit(repository: repository, branchId: 'b-1');
      await cubit.load();

      // The same branch is the same answer, so a rebuild asks for nothing.
      await cubit.setBranch('b-1');
      expect(repository.plansReadFor, ['b-1']);

      await cubit.setBranch('b-2');
      expect(repository.plansReadFor, ['b-1', 'b-2']);
      await cubit.close();
    });

    test(
      'a history read for a subscription the customer left cannot land',
      () async {
        final repository = _FakeRepository()
          ..plansToReturn = [_plan()]
          ..subscription = const CustomerSubscription(
            id: 'sub-1',
            planId: 'plan-1',
          )
          ..usageBySubscription['sub-1'] = const [
            SubscriptionUsage(
              id: 'u1',
              subscriptionId: 'sub-1',
              branchId: 'b1',
            ),
          ];
        final gate = Completer<void>();
        repository.usageGates['sub-1'] = gate;
        final cubit = SubscriptionCubit(repository: repository);

        final first = cubit.load();
        // Let the first read reach the history it is now waiting on.
        await Future<void>.delayed(Duration(milliseconds: 1));

        repository
          ..subscription = const CustomerSubscription(
            id: 'sub-2',
            planId: 'plan-1',
          )
          ..usageBySubscription['sub-2'] = const [
            SubscriptionUsage(
              id: 'u2',
              subscriptionId: 'sub-2',
              branchId: 'b1',
            ),
          ];
        await cubit.load();

        gate.complete();
        await first;

        expect(cubit.state.usage?.single.id, 'u2');
        expect(repository.usageReadFor, ['sub-1', 'sub-2']);
        await cubit.close();
      },
    );
  });

  group('localised model', () {
    test('a plan row with only one language filled still reads', () {
      AppLocale.instance.debugSet(AppLanguage.english);
      const arabicOnly = SubscriptionPlan(
        id: 'p',
        code: 'c',
        nameAr: 'باقة',
        nameEn: '',
        price: 1,
      );
      expect(arabicOnly.name, 'باقة');

      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(arabicOnly.name, 'باقة');
      expect(
        const CustomerSubscription(
          id: 's',
          planId: 'p',
          status: 'pending_payment',
        ).statusLabel,
        S.subscriptionPendingPayment,
      );
    });

    test('an unknown status is shown as it arrived', () {
      expect(
        const CustomerSubscription(
          id: 's',
          planId: 'p',
          status: 'refunded',
        ).statusLabel,
        'refunded',
      );
    });

    test('a product with no image still has a name', () {
      AppLocale.instance.debugSet(AppLanguage.english);
      const product = SubscriptionPlanProduct(
        id: 'x',
        nameAr: 'قهوة',
        nameEn: 'Coffee',
      );
      expect(product.name, 'Coffee');
    });

    test('a cup balance never reads as a debt', () {
      const spent = CustomerSubscription(
        id: 's',
        planId: 'p',
        cupsEntitled: 2,
        cupsUsed: 5,
      );
      expect(spent.availableCups, 0);
    });

    test('a usage row is titled by how the cup left', () {
      AppLocale.instance.debugSet(AppLanguage.english);
      const qr = SubscriptionUsage(id: 'u', subscriptionId: 's', branchId: 'b');
      expect(qr.title, S.usageByQr);

      const cashier = SubscriptionUsage(
        id: 'u',
        subscriptionId: 's',
        branchId: 'b',
        method: 'cashier',
      );
      expect(cashier.title, S.usageByCashier);

      // A method this app has never been told about is a redemption, not the
      // column word the customer has to decode.
      const kiosk = SubscriptionUsage(
        id: 'u',
        subscriptionId: 's',
        branchId: 'b',
        method: 'kiosk',
      );
      expect(kiosk.title, S.usageUnknownMethod);
      expect(kiosk.methodLabel, isNot('kiosk'));
    });

    test('a policy the app has not been told about is shown as it arrived', () {
      AppLocale.instance.debugSet(AppLanguage.english);
      final plan = SubscriptionPlan(
        id: 'p',
        code: 'c',
        nameAr: '',
        nameEn: 'Plan',
        price: 1,
        renewalPolicy: 'partner',
        productScope: 'menu',
        bonusType: 'credit',
      );
      expect(plan.renewalPolicyLabel, 'partner');
      expect(plan.productScopeLabel, 'menu');
      expect(plan.coversSelectedProducts, isFalse);
      expect(plan.offersBonus, isTrue);

      // The shipped defaults read as the sentences the app was built for.
      expect(_plan().renewalPolicyLabel, S.renewalManual);
      expect(_plan().productScopeLabel, S.allProducts);
      expect(_plan().offersBonus, isFalse);
      expect(_plan().coversSelectedProducts, isFalse);
    });

    test('cups and days read as counts, not as bare numbers', () {
      AppLocale.instance.debugSet(AppLanguage.english);
      expect(S.cupsCount(1), '1 cup');
      expect(S.cupsCount(3), '3 cups');
      expect(S.daysCount(30), '30 days');

      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(S.cupsCount(1), '1 كوب');
      expect(S.daysCount(30), '30 يوم');
    });
  });
}
