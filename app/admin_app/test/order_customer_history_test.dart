import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/customer_previous_order_item.dart';
import 'package:admin_app/features/orders/presentation/widgets/customer_previous_orders.dart';

/// ثمانية طلبات: أكثر من السقف الذي كان القسم يطبعه، فيظهر الصمت أو الطبع.
List<AdminOrder> _orders(int count) => [
  for (var index = 1; index <= count; index++)
    AdminOrder(
      id: 'o$index',
      orderNumber: '3${index.toString().padLeft(3, '0')}',
      customerName: 'Customer',
      fulfillmentType: 'delivery',
      status: 'delivered',
      paymentStatus: 'paid',
      subtotal: 20,
      discountTotal: 0,
      deliveryFee: 0,
      taxTotal: 0,
      grandTotal: 20,
      placedAt: DateTime(2026, 10, index),
    ),
];

Future<void> _pump(WidgetTester tester, List<AdminOrder> orders) async {
  tester.view.physicalSize = const Size(1100, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CustomerPreviousOrders(
            orders: orders,
            loading: false,
            failed: false,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('every previous order is printed, not the first five', (
    tester,
  ) async {
    await _pump(tester, _orders(8));

    expect(tester.takeException(), isNull);
    expect(
      tester.widgetList<CustomerPreviousOrderItem>(
        find.byType(CustomerPreviousOrderItem),
      ),
      hasLength(8),
    );
    // الشارة فوق القسم عددُها كله، فالسقف الخامس كان يجعلها تكذب.
    expect(find.text('#3001'), findsOneWidget);
    expect(find.text('#3008'), findsOneWidget);
  });

  testWidgets('no orders leaves the empty line, not five blanks', (
    tester,
  ) async {
    await _pump(tester, const <AdminOrder>[]);

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomerPreviousOrderItem), findsNothing);
  });
}
