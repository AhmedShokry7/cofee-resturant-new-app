import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/navigation/app_route_generator.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';
import 'package:new_coffee/features/orders/presentation/views/track_order_page.dart';

class _FakeOrdersRepository implements OrdersRepository {
  _FakeOrdersRepository({List<OrderItemModel>? orders, this.fail = false})
    : _orders = orders ?? const [];

  final List<OrderItemModel> _orders;
  bool fail;

  int listCalls = 0;
  int cancelCalls = 0;
  String? cancelledId;
  bool cancelFails = false;

  @override
  Future<List<OrderItemModel>> listOrders({
    OrderStatus? status,
    int limit = 100,
  }) async {
    listCalls++;
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
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    cancelCalls++;
    cancelledId = orderId;
    if (cancelFails) throw StateError('order already delivered');
  }

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
  databaseStatus: 'preparing',
  grandTotal: grandTotal,
);

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 1200) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpPage(WidgetTester tester, OrdersRepository repository) {
  // The repository sits above the navigator because a pushed route is built by
  // the root navigator and never inherits a screen-level provider.
  return tester.pumpWidget(
    RepositoryProvider<OrdersRepository>.value(
      value: repository,
      child: MaterialApp(
        onGenerateRoute: AppRouteGenerator.onGenerateRoute,
        home: const OrdersPage(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  testWidgets('renders one card per order with number, items and total', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeOrdersRepository(
      orders: [
        _line(
          id: 'l1',
          orderId: 'o1',
          orderNumber: 'ORD-1',
          status: OrderStatus.active,
          quantity: 2,
          grandTotal: 56,
        ),
        _line(
          id: 'l2',
          orderId: 'o1',
          orderNumber: 'ORD-1',
          status: OrderStatus.active,
          quantity: 1,
          grandTotal: 56,
        ),
        _line(
          id: 'l3',
          orderId: 'o2',
          orderNumber: 'ORD-2',
          status: OrderStatus.active,
          quantity: 1,
          grandTotal: 30,
        ),
      ],
    );

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text(S.orderNumber('ORD-1')), findsOneWidget);
    expect(find.text(S.orderNumber('ORD-2')), findsOneWidget);
    expect(find.text('${S.itemsCount}: 3'), findsOneWidget);
    expect(find.text('56.00'), findsOneWidget);
    expect(find.text('30.00'), findsOneWidget);
  });

  testWidgets('an empty history shows the empty state', (tester) async {
    await _setSurface(tester);
    final repository = _FakeOrdersRepository();

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text(S.noOrders), findsOneWidget);
    expect(find.text(S.ordersEmptyHint), findsOneWidget);
  });

  testWidgets('a repository failure shows the error state with retry', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeOrdersRepository(fail: true);

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text(S.couldNotLoadOrders), findsOneWidget);
    expect(find.text(S.tryAgain), findsOneWidget);

    await tester.tap(find.text(S.tryAgain));
    await tester.pumpAndSettle();
    expect(repository.listCalls, greaterThan(1));
  });

  testWidgets('pull-to-refresh re-fetches the current tab', (tester) async {
    await _setSurface(tester);
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

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();
    expect(repository.listCalls, 1);

    await tester.fling(
      find.text(S.orderNumber('ORD-1')),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(repository.listCalls, 2);
  });

  testWidgets('a cancel made on the tracking screen re-reads the list', (
    tester,
  ) async {
    await _setSurface(tester);
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

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();
    final readsBeforeCancel = repository.listCalls;

    await tester.tap(find.text(S.trackOrder));
    await tester.pumpAndSettle();
    expect(find.byType(TrackOrderPage), findsOneWidget);

    await tester.tap(find.text(S.cancelOrder));
    await tester.pumpAndSettle();

    expect(repository.cancelledId, 'o1');
    expect(find.byType(TrackOrderPage), findsNothing);
    // The route came back saying the order is cancelled, so the list the
    // customer returns to cannot still be showing the row it had.
    expect(repository.listCalls, greaterThan(readsBeforeCancel));
  });

  testWidgets('a cancel the server refused leaves the list alone', (
    tester,
  ) async {
    await _setSurface(tester);
    final repository = _FakeOrdersRepository(
      orders: [
        _line(
          id: 'l1',
          orderId: 'o1',
          orderNumber: 'ORD-1',
          status: OrderStatus.active,
        ),
      ],
    )..cancelFails = true;

    await _pumpPage(tester, repository);
    await tester.pumpAndSettle();
    final readsBefore = repository.listCalls;

    await tester.tap(find.text(S.trackOrder));
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.cancelOrder));
    await tester.pumpAndSettle();

    expect(find.byType(TrackOrderPage), findsOneWidget);
    expect(find.text(S.couldNotCancelOrder), findsOneWidget);
    expect(repository.listCalls, readsBefore);
  });
}
