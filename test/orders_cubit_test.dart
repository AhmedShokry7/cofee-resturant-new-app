import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/presentation/manager/orders/orders_cubit.dart';

class _FakeOrdersRepository implements OrdersRepository {
  _FakeOrdersRepository({List<OrderItemModel>? orders, this.fail = false})
    : _orders = orders ?? const [];

  final List<OrderItemModel> _orders;
  bool fail;

  int listCalls = 0;
  OrderStatus? lastStatus;

  @override
  Future<List<OrderItemModel>> listOrders({
    OrderStatus? status,
    int limit = 100,
  }) async {
    listCalls++;
    lastStatus = status;
    if (fail) throw StateError('Could not load orders');
    if (status == null) return _orders;
    return _orders.where((line) => line.status == status).toList();
  }

  @override
  Future<void> syncCart({
    required String branchId,
    required List<PlaceOrderLine> lines,
  }) => throw UnimplementedError();

  @override
  Future<PlacedOrder> placeOrder({
    required String branchId,
    required List<PlaceOrderLine> lines,
    required String idempotencyKey,
    String fulfillmentType = 'pickup',
    String? deliveryZoneId,
    String? addressId,
    String? couponCode,
    String? note,
  }) => throw UnimplementedError();

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) =>
      throw UnimplementedError();

  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) =>
      throw UnimplementedError();
}

OrderItemModel _line({
  required String id,
  required String orderId,
  required String orderNumber,
  required OrderStatus status,
  int quantity = 1,
  double unitPrice = 25,
  double? grandTotal,
  String fulfillmentType = 'pickup',
}) => OrderItemModel(
  id: id,
  product: ProductModel(
    id: 'product-$id',
    nameEn: 'Latte $id',
    nameAr: 'لاتيه $id',
    price: unitPrice,
    image: AppImages.product,
  ),
  status: status,
  quantity: quantity,
  orderId: orderId,
  orderNumber: orderNumber,
  unitPrice: unitPrice,
  lineTotal: unitPrice * quantity,
  placedAt: DateTime.utc(2026, 10, 1, 10),
  fulfillmentType: fulfillmentType,
  databaseStatus: status == OrderStatus.active ? 'preparing' : 'completed',
  grandTotal: grandTotal,
);

void main() {
  group('OrdersCubit', () {
    test('loads the authenticated customer orders on construction', () async {
      final repository = _FakeOrdersRepository(
        orders: [
          _line(
            id: 'l1',
            orderId: 'o1',
            orderNumber: 'ORD-1',
            status: OrderStatus.active,
          ),
        ],
      );
      final cubit = OrdersCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);

      expect(repository.listCalls, 1);
      expect(repository.lastStatus, OrderStatus.active);
      expect(cubit.state.orders, hasLength(1));
      expect(cubit.state.isEmpty, isFalse);
    });

    test('lines of one order group into a single card with real totals', () async {
      final repository = _FakeOrdersRepository(
        orders: [
          _line(
            id: 'l1',
            orderId: 'o1',
            orderNumber: 'ORD-1',
            status: OrderStatus.active,
            quantity: 2,
            unitPrice: 25,
            grandTotal: 56,
          ),
          _line(
            id: 'l2',
            orderId: 'o1',
            orderNumber: 'ORD-1',
            status: OrderStatus.active,
            quantity: 1,
            unitPrice: 10,
            grandTotal: 56,
          ),
        ],
      );
      final cubit = OrdersCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);

      final groups = cubit.state.grouped;
      expect(groups, hasLength(1));
      expect(groups.single.itemCount, 3);
      expect(groups.single.displayNumber, 'ORD-1');
      expect(groups.single.grandTotal, 56);
    });

    test('an empty history is an empty state, not an error', () async {
      final cubit = OrdersCubit(repository: _FakeOrdersRepository());
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);

      expect(cubit.state.isEmpty, isTrue);
      expect(cubit.state.error, isNull);
    });

    test('a repository failure surfaces an error state', () async {
      final cubit = OrdersCubit(
        repository: _FakeOrdersRepository(fail: true),
      );
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => state.error != null);

      expect(cubit.state.error, contains('Could not load orders'));
      expect(cubit.state.orders, isEmpty);
    });

    test('a signed-out repository reports signedOut instead of error', () async {
      final repository = _SignedOutRepository();
      final cubit = OrdersCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => state.signedOut);

      expect(cubit.state.signedOut, isTrue);
      expect(cubit.state.orders, isEmpty);
      expect(cubit.state.error, isNull);
    });

    test('switching tabs re-queries with the new status', () async {
      final repository = _FakeOrdersRepository(
        orders: [
          _line(
            id: 'l1',
            orderId: 'o1',
            orderNumber: 'ORD-1',
            status: OrderStatus.completed,
          ),
        ],
      );
      final cubit = OrdersCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      expect(repository.lastStatus, OrderStatus.active);
      expect(cubit.state.orders, isEmpty, reason: 'active tab hides completed');

      await cubit.selectStatus(OrderStatus.completed);

      expect(repository.lastStatus, OrderStatus.completed);
      expect(cubit.state.orders, hasLength(1));
    });

    test('refresh re-reads the current tab', () async {
      final repository = _FakeOrdersRepository();
      final cubit = OrdersCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      expect(repository.listCalls, 1);

      await cubit.refresh();
      expect(repository.listCalls, 2);
    });
  });
}

class _SignedOutRepository implements OrdersRepository {
  @override
  Future<List<OrderItemModel>> listOrders({
    OrderStatus? status,
    int limit = 100,
  }) async => throw const OrderSignInRequiredException();

  @override
  Future<void> syncCart({
    required String branchId,
    required List<PlaceOrderLine> lines,
  }) => throw UnimplementedError();

  @override
  Future<PlacedOrder> placeOrder({
    required String branchId,
    required List<PlaceOrderLine> lines,
    required String idempotencyKey,
    String fulfillmentType = 'pickup',
    String? deliveryZoneId,
    String? addressId,
    String? couponCode,
    String? note,
  }) => throw UnimplementedError();

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) =>
      throw UnimplementedError();

  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) =>
      throw UnimplementedError();
}
