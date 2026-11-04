import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/navigation/app_route_generator.dart';
import 'package:new_coffee/core/navigation/notification_routes.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/notifications/data/services/push_service.dart';
import 'package:new_coffee/features/orders/data/model/order_group.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/presentation/views/order_details_by_id_page.dart';
import 'package:new_coffee/features/orders/presentation/views/order_details_page.dart';

/// The last step of a notification tap: the navigator resolves the route the
/// routing helper chose, and the page that owns an id reads that one order.
///
/// The app only ever pushes [OrderDetailsPage.routeName], with an id when the
/// row names an order and with the rows themselves when the orders list opens
/// one of its own cards. This file holds both contracts in one place, because a
/// change that sent a plain id to the frozen details page would have drawn an
/// empty receipt instead of failing loudly.
class _FakeOrdersRepository implements OrdersRepository {
  _FakeOrdersRepository(this.lines);

  final List<OrderItemModel> lines;
  int lastLimit = 0;

  @override
  Future<List<OrderItemModel>> listOrders({
    OrderStatus? status,
    int limit = 100,
  }) async {
    lastLimit = limit;
    return status == null
        ? lines
        : lines.where((l) => l.status == status).toList();
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

/// The app as the navigator sees it: the real generator, the repository the
/// pages read, and a home that owns nothing but the back button.
Future<void> _pumpApp(
  WidgetTester tester,
  _FakeOrdersRepository repository,
) async {
  tester.view.physicalSize = const Size(390, 1600) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    RepositoryProvider<OrdersRepository>.value(
      value: repository,
      child: MaterialApp(
        onGenerateRoute: AppRouteGenerator.onGenerateRoute,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
}

Future<void> _push(WidgetTester tester, Object? arguments) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.pushNamed(OrderDetailsPage.routeName, arguments: arguments);
  await tester.pumpAndSettle();
}

void main() {
  const orderId = '550e8400-e29b-41d4-a716-446655440000';

  group('the route a notification id resolves to', () {
    testWidgets('an id opens the page that reads that one order', (
      tester,
    ) async {
      final repository = _FakeOrdersRepository([
        _line(id: 'a', orderId: orderId),
        _line(id: 'b', orderId: orderId, quantity: 2),
      ]);
      await _pumpApp(tester, repository);

      await _push(tester, orderId);

      expect(find.byType(OrderDetailsByIdPage), findsOneWidget);
      expect(repository.lastLimit, greaterThan(100));
      // The id is only a lookup key, so the invoice comes from the read: both
      // lines of the order are drawn, not the single row the list would pass.
      expect(find.byType(OrderDetailsPage), findsOneWidget);
      expect(find.text(S.orderNotInAccount), findsNothing);
    });

    testWidgets('an id of no order in the account says so', (tester) async {
      final repository = _FakeOrdersRepository([
        _line(id: 'other', orderId: '22222222-2222-2222-2222-222222222222'),
      ]);
      await _pumpApp(tester, repository);

      await _push(tester, orderId);

      expect(find.byType(OrderDetailsByIdPage), findsOneWidget);
      expect(find.byType(OrderDetailsPage), findsNothing);
      expect(find.text(S.orderNotInAccount), findsOneWidget);
    });
  });

  group('the routes the orders list already used', () {
    testWidgets('a group of lines still opens the frozen details', (
      tester,
    ) async {
      await _pumpApp(tester, _FakeOrdersRepository(const []));

      final line = _line(id: 'c', orderId: 'order-3');
      await _push(tester, OrderGroup(header: line, lines: [line]));

      expect(find.byType(OrderDetailsByIdPage), findsNothing);
      expect(find.byType(OrderDetailsPage), findsOneWidget);
    });
  });

  group('a push that opened the app', () {
    testWidgets('the shell replays the id it stored', (tester) async {
      final repository = _FakeOrdersRepository([
        _line(id: 'a', orderId: orderId),
      ]);
      await _pumpApp(tester, repository);

      // What the tap handler stores when the app was closed, and what the
      // shell of the first frame replays once a navigator exists.
      final open = openForNotification(
        relatedEntityType: 'order',
        type: 'order_status',
        relatedEntityId: orderId,
      );
      expect(open, isNotNull);
      PushService.setPendingRoute(open!);

      final stored = PushService.takePendingRoute();
      expect(stored, isNotNull);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed(stored!.route, arguments: stored.entityId);
      await tester.pumpAndSettle();

      expect(stored.route, OrderDetailsPage.routeName);
      expect(find.byType(OrderDetailsByIdPage), findsOneWidget);
      expect(find.byType(OrderDetailsPage), findsOneWidget);
    });
  });
}
