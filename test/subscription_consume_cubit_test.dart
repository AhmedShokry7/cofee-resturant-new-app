import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/subscriptions/presentation/manager/subscription_consume/subscription_consume_cubit.dart';

class _FakeConsumeRepository implements SubscriptionRepository {
  final List<Map<String, String>> requests = [];
  int remaining = 3;
  Object? error;

  @override
  Future<int> consumeQr({
    required String token,
    required String branchId,
    required String productId,
    int quantity = 1,
    required String idempotencyKey,
  }) async {
    requests.add({
      'token': token,
      'branchId': branchId,
      'productId': productId,
      'quantity': '$quantity',
      'key': idempotencyKey,
    });
    final failure = error;
    if (failure != null) throw failure;
    return remaining;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('SubscriptionConsumeCubit', () {
    test('a quantity that is not a number deducts nothing', () async {
      final repository = _FakeConsumeRepository();
      final cubit = SubscriptionConsumeCubit(repository: repository);

      await cubit.consume(
        token: 'qr-1',
        branchId: 'b-1',
        productId: 'p-1',
        quantityText: 'abc',
      );

      expect(repository.requests, isEmpty);
      expect(cubit.state.message, S.invalidQuantity);
      await cubit.close();
    });

    test('a quantity of zero deducts nothing', () async {
      final repository = _FakeConsumeRepository();
      final cubit = SubscriptionConsumeCubit(repository: repository);

      await cubit.consume(
        token: 'qr-1',
        branchId: 'b-1',
        productId: 'p-1',
        quantityText: '0',
      );

      expect(repository.requests, isEmpty);
      await cubit.close();
    });

    test('a retry after a failure sends the same idempotency key', () async {
      final repository = _FakeConsumeRepository()
        ..error = StateError('the request timed out');
      final cubit = SubscriptionConsumeCubit(repository: repository);

      await cubit.consume(
        token: 'qr-1',
        branchId: 'b-1',
        productId: 'p-1',
        quantityText: '1',
      );
      await cubit.consume(
        token: 'qr-1',
        branchId: 'b-1',
        productId: 'p-1',
        quantityText: '1',
      );

      expect(repository.requests, hasLength(2));
      expect(
        repository.requests.first['key'],
        repository.requests.last['key'],
        reason: 'the cashier tapped once; the server must see one deduction',
      );
      expect(cubit.state.message, S.couldNotDeductCups);
      await cubit.close();
    });

    test('a second deduction of the same cup is a new intent', () async {
      final repository = _FakeConsumeRepository();
      final cubit = SubscriptionConsumeCubit(repository: repository);

      await cubit.consume(
        token: 'qr-1',
        branchId: 'b-1',
        productId: 'p-1',
        quantityText: '1',
      );
      await cubit.consume(
        token: 'qr-1',
        branchId: 'b-1',
        productId: 'p-1',
        quantityText: '1',
      );

      expect(
        repository.requests.first['key'],
        isNot(repository.requests.last['key']),
      );
      expect(cubit.state.message, S.cupsRemaining(3));
      await cubit.close();
    });

    test('the token and product are trimmed before they are sent', () async {
      final repository = _FakeConsumeRepository();
      final cubit = SubscriptionConsumeCubit(repository: repository);

      await cubit.consume(
        token: '  qr-1  ',
        branchId: 'b-1',
        productId: '  p-1 ',
        quantityText: ' 2 ',
      );

      expect(repository.requests.single['token'], 'qr-1');
      expect(repository.requests.single['productId'], 'p-1');
      expect(repository.requests.single['quantity'], '2');
      await cubit.close();
    });
  });
}
