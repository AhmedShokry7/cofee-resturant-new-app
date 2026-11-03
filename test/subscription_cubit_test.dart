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
  final List<String> subscribeKeys = [];

  int _subscribeCalls = 0;

  /// Fails the first subscribe attempt only, so a retry can be compared with
  /// the attempt that came before it.
  Object? firstSubscribeError;

  @override
  Future<List<SubscriptionPlan>> plans({String? branchId}) async {
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
    final error = usageError;
    if (error != null) throw error;
    return usageToReturn;
  }

  @override
  Future<CustomerSubscription> subscribe({
    required String planId,
    required String idempotencyKey,
  }) async {
    subscribeKeys.add(idempotencyKey);
    _subscribeCalls++;
    if (_subscribeCalls == 1 && firstSubscribeError != null) {
      throw firstSubscribeError!;
    }
    return subscription = CustomerSubscription(
      id: 'sub-$_subscribeCalls',
      planId: planId,
    );
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
      expect(cubit.state.error, isNull);
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
        expect(cubit.state.error, isNotNull);
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
  });
}
