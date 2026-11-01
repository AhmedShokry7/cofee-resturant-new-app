import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/presentation/manager/order_tracking/order_tracking_cubit.dart';

class _FakeOrdersRepository implements OrdersRepository {
  _FakeOrdersRepository({this.events = const [], this.error});

  List<OrderStatusEvent> events;
  Object? error;

  /// Every order id the screen asked for, in order.
  final List<String> readFor = [];

  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) async {
    readFor.add(orderId);
    if (error != null) throw error!;
    return events;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('OrderTrackingCubit', () {
    test('the history of the order the screen opened is read', () async {
      final repository = _FakeOrdersRepository(
        events: const [OrderStatusEvent(toStatus: 'preparing')],
      );
      final cubit = OrderTrackingCubit(
        repository: repository,
        orderId: 'order-7',
      );
      addTearDown(cubit.close);
      await cubit.load();

      expect(repository.readFor, ['order-7']);
      expect(cubit.state.events, hasLength(1));
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.failed, isFalse);
    });

    test('an order with no history is empty, not still loading', () async {
      final cubit = OrderTrackingCubit(
        repository: _FakeOrdersRepository(),
        orderId: 'order-7',
      );
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.events, isEmpty);
      expect(cubit.state.isLoading, isFalse);
    });

    test('a failed read is reported and a retry replaces it', () async {
      final repository = _FakeOrdersRepository(error: StateError('offline'));
      final cubit = OrderTrackingCubit(repository: repository, orderId: 'o');
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.failed, isTrue);
      expect(cubit.state.events, isNull);

      repository.error = null;
      repository.events = const [OrderStatusEvent(toStatus: 'delivered')];
      await cubit.load();

      expect(cubit.state.failed, isFalse);
      expect(cubit.state.events, hasLength(1));
    });
  });
}
