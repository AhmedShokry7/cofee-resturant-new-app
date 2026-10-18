import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

class _FakeOrdersRepository implements OrdersRepository {
  _FakeOrdersRepository({required this.orders});
  final List<OrderItemModel> orders;
  @override
  Future<List<OrderItemModel>> listOrders({OrderStatus? status, int limit = 100}) async => orders;
  @override
  Future<void> syncCart({required String branchId, required List<PlaceOrderLine> lines}) async {}
  @override
  Future<PlacedOrder> placeOrder({required String branchId, required List<PlaceOrderLine> lines, required String idempotencyKey, String fulfillmentType = 'pickup', String? deliveryZoneId, String? addressId, String? couponCode, String? note}) async => throw UnimplementedError();
  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}
  @override
  Future<List<OrderStatusEvent>> orderHistory(String orderId) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('tap order opens details', (tester) async {
    tester.view.physicalSize = const Size(360,1200)*3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final orders = [
      OrderItemModel(
        id: 'l1', product: ProductModel(id:'p1', nameEn:'Latte', nameAr:'Latte', price:25, image: AppImages.product),
        status: OrderStatus.active, quantity:1, orderId:'o1', orderNumber:'ORD-1', unitPrice:25, lineTotal:25, placedAt: DateTime.utc(2026,10,1,10), databaseStatus:'preparing', grandTotal:25,
      ),
    ];

    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(360,690),
      builder: (context, _) => MaterialApp(
        onGenerateRoute: AppRouteGenerator.onGenerateRoute,
        home: RepositoryProvider<OrdersRepository>.value(value: _FakeOrdersRepository(orders: orders), child: const OrdersPage()),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ORD-1'.replaceAll('ORD-1', S.orderNumber('ORD-1'))));
    await tester.pumpAndSettle();
    expect(find.text(S.orderDetails), findsOneWidget);
  });
}
