import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_cubit.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_detail_controller.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_add_product_button.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_customer_section.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_detail_body.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_detail_status_control.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_items_list.dart';

AdminOrder _order() => AdminOrder(
  id: 'o1',
  orderNumber: '1001',
  userId: 'c1',
  customerName: 'Ahmed',
  customerEmail: 'ahmed@example.com',
  branchNameAr: 'الفرع الرئيسي',
  branchNameEn: 'Main branch',
  fulfillmentType: 'delivery',
  status: 'confirmed',
  paymentStatus: 'unpaid',
  subtotal: 20,
  discountTotal: 0,
  deliveryFee: 0,
  taxTotal: 0,
  grandTotal: 20,
  placedAt: DateTime(2026, 10, 20, 14, 30),
  items: const [
    AdminOrderItem(
      id: 'i1',
      productId: 'p1',
      productNameEn: 'Latte',
      productNameAr: 'لاتيه',
      quantity: 2,
      unitPrice: 10,
      lineTotal: 20,
    ),
  ],
);

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _body(OrderDetailController controller) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: OrderDetailBody(
          controller: controller,
          onStatusChanged: (_) {},
          onRemoveItem: (_) {},
          onAddProduct: () {},
          navigationOrders: const [],
          onSelectOrder: (_) {},
        ),
      ),
    ),
  ),
);

OrderDetailController _controller({bool canManage = true}) {
  final cubit = AdminOrderCubit();
  final controller = OrderDetailController(
    cubit: cubit,
    order: _order(),
    canManage: canManage,
  );
  addTearDown(() {
    controller.dispose();
    cubit.close();
  });
  return controller;
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('order details fit a narrow screen without overflow', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 900));
    await tester.pumpWidget(_body(_controller()));
    await tester.pumpAndSettle();

    expect(find.text('#1001'), findsOneWidget);
    expect(find.text('Main branch'), findsOneWidget);
    expect(find.text('Latte'), findsOneWidget);
    expect(find.text(S.grandTotal), findsNWidgets(2));
    expect(find.text(S.orderItemsLabel), findsWidgets);
    expect(find.text(S.paymentInfoTitle), findsOneWidget);
    expect(find.text(S.customer), findsOneWidget);
    expect(find.text(S.ordersCustomerHistory), findsOneWidget);
    expect(find.text(S.fulfillmentInfoTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide screens place the customer column beside the items', (
    tester,
  ) async {
    _setViewport(tester, const Size(1280, 1000));
    await tester.pumpWidget(_body(_controller()));
    await tester.pumpAndSettle();

    final items = tester.getTopLeft(find.byType(OrderItemsList));
    final customer = tester.getTopLeft(find.byType(OrderCustomerSection));
    expect(customer.dy, moreOrLessEquals(items.dy));
    expect(customer.dx, greaterThan(items.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('arabic details show localized section labels', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    _setViewport(tester, const Size(390, 900));
    await tester.pumpWidget(_body(_controller()));
    await tester.pumpAndSettle();

    expect(find.text('العميل'), findsOneWidget);
    expect(find.text('الإجمالي النهائي'), findsNWidgets(2));
    expect(find.text('Customer'), findsNothing);
    expect(find.text('Grand total'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a manager gets the controls that write', (tester) async {
    _setViewport(tester, const Size(390, 1400));
    await tester.pumpWidget(_body(_controller()));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailStatusControl), findsOneWidget);
    expect(find.byType(OrderAddProductButton), findsOneWidget);
  });

  testWidgets('a reader without the write permission gets none of them', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 1400));
    await tester.pumpWidget(_body(_controller(canManage: false)));
    await tester.pumpAndSettle();

    expect(find.text('#1001'), findsOneWidget);
    expect(find.byType(OrderDetailStatusControl), findsNothing);
    expect(find.byType(OrderAddProductButton), findsNothing);
    final remove = tester.widget<IconButton>(
      find.descendant(
        of: find.byType(OrderItemsList),
        matching: find.byType(IconButton),
      ),
    );
    expect(remove.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
