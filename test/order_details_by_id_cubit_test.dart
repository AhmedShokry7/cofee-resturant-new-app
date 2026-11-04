import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/presentation/manager/order_details_by_id/order_details_by_id_cubit.dart';

/// A notification names an order by id, and the id can be months old. This file
/// holds the two ways that id gets answered: the scoped read the server serves
/// directly, and the recent-history scan a repository without that capability
/// still falls back to.
class _HistoryOnlyRepository implements OrdersRepository {
  _HistoryOnlyRepository(this.lines);

  final List<OrderItemModel> lines;
  int listCalls = 0;
  int lastLimit = 0;

  @override
  Future<List<OrderItemModel>> listOrders({
    OrderStatus? status,
    int limit = 100,
  }) async {
    listCalls++;
    lastLimit = limit;
    return lines;
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

/// The shape of the real Supabase repository: it answers one order by id and
/// never needs the history window for it.
class _LookupRepository extends _HistoryOnlyRepository
    implements OrderLinesRepository {
  _LookupRepository(super.lines, {this.knownIds});

  /// When set, only these ids are served - the way an owner-scoped query
  /// answers an id that is not this customer's order.
  final Set<String>? knownIds;
  List<String> asked = [];
  List<OrderItemModel>? scopedResult;

  @override
  Future<List<OrderItemModel>> orderLines(String orderId) async {
    asked.add(orderId);
    if (knownIds != null && !knownIds!.contains(orderId)) return const [];
    return scopedResult ??
        lines.where((line) => line.orderId == orderId).toList();
  }
}

OrderItemModel _line({
  required String id,
  required String orderId,
  int quantity = 1,
}) => OrderItemModel(
  id: id,
  product: ProductModel(
    id: 'product-$id',
    nameEn: 'Latte $id',
    nameAr: 'لاتيه $id',
    price: 25,
    image: AppImages.product,
  ),
  status: OrderStatus.completed,
  quantity: quantity,
  orderId: orderId,
  orderNumber: 'ORD-$id',
  unitPrice: 25,
  lineTotal: 25.0 * quantity,
  placedAt: DateTime.utc(2026, 10, 1, 10),
  databaseStatus: 'completed',
  grandTotal: 50,
);

void main() {
  const orderId = '550e8400-e29b-41d4-a716-446655440000';

  group('the order a notification names, read by id', () {
    test('the scoped read is asked and the history is not', () async {
      final repository = _LookupRepository([
        _line(id: 'old-line', orderId: orderId),
      ]);
      final cubit = OrderDetailsByIdCubit(
        repository: repository,
        orderId: orderId,
      );
      await pumpEventQueue();

      expect(repository.asked, [orderId]);
      // The window is gone from the production path: no history read at all.
      expect(repository.listCalls, 0);
      expect(cubit.state.notFound, isFalse);
      expect(cubit.state.order?.orderId, orderId);
      expect(cubit.state.order?.lines.length, 1);
      await cubit.close();
    });

    test('an older order than any window still opens', () async {
      // The same row, seen through the two paths: the scan has to have it in
      // the recent lines, the lookup does not care when it was placed.
      final history = _HistoryOnlyRepository(const []);
      final scanned = OrderDetailsByIdCubit(
        repository: history,
        orderId: orderId,
      );
      await pumpEventQueue();
      expect(scanned.state.notFound, isTrue);
      await scanned.close();

      final lookup = _LookupRepository(const [], knownIds: {orderId})
        ..scopedResult = [_line(id: 'ancient', orderId: orderId)];
      final scoped = OrderDetailsByIdCubit(
        repository: lookup,
        orderId: orderId,
      );
      await pumpEventQueue();
      expect(scoped.state.notFound, isFalse);
      expect(scoped.state.order?.displayNumber, 'ORD-ancient');
      await scoped.close();
    });

    test('an id that is not this customer’s order says not found', () async {
      final repository = _LookupRepository(const [], knownIds: {});
      final cubit = OrderDetailsByIdCubit(
        repository: repository,
        orderId: orderId,
      );
      await pumpEventQueue();

      expect(repository.asked, [orderId]);
      expect(cubit.state.notFound, isTrue);
      expect(cubit.state.order, isNull);
      await cubit.close();
    });
  });

  group('the history scan a repository without the lookup falls back to', () {
    test('the recent lines are read once, with the whole window', () async {
      final repository = _HistoryOnlyRepository([
        _line(id: 'a', orderId: 'order-1'),
        _line(id: 'b', orderId: orderId),
        _line(id: 'c', orderId: orderId),
      ]);
      final cubit = OrderDetailsByIdCubit(
        repository: repository,
        orderId: orderId,
      );
      await pumpEventQueue();

      expect(repository.listCalls, 1);
      expect(repository.lastLimit, OrderDetailsByIdCubit.historyLimit);
      // Only the group the id names, with every one of its lines.
      expect(cubit.state.order?.lines.map((line) => line.id), ['b', 'c']);
      await cubit.close();
    });
  });

  group('an id that is not one', () {
    test('the value is checked before it reaches a uuid column', () {
      expect(Db.uuidOrNull(orderId), orderId);
      // The value is kept as it arrived - Postgres reads a uuid in either
      // case - and only the shape is checked.
      expect(Db.uuidOrNull(orderId.toUpperCase()), orderId.toUpperCase());
      expect(Db.uuidOrNull('  $orderId  '), orderId);
      expect(Db.uuidOrNull(''), isNull);
      expect(Db.uuidOrNull('   '), isNull);
      expect(Db.uuidOrNull(null), isNull);
      expect(Db.uuidOrNull('550e8400-e29b-41d4-a716-44665544000'), isNull);
      expect(Db.uuidOrNull('orders/1'), isNull);
      expect(Db.uuidOrNull(42), isNull);
    });

    test('a repository without the lookup is not handed a wild id', () async {
      // The navigation layer only ever passes a checked id, so the page reads
      // as not-found rather than as a server error on a uuid column.
      final repository = _HistoryOnlyRepository(const []);
      final cubit = OrderDetailsByIdCubit(
        repository: repository,
        orderId: 'not-a-uuid',
      );
      await pumpEventQueue();

      expect(cubit.state.notFound, isTrue);
      await cubit.close();
    });
  });
}
