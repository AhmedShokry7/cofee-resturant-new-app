import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_page_body.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_summary_metric_format.dart';

AdminOrder _order() => const AdminOrder(
  id: 'o1',
  orderNumber: '1001',
  customerName: 'Ahmed',
  fulfillmentType: 'delivery',
  status: 'pending',
  paymentStatus: 'paid',
  subtotal: 20,
  discountTotal: 0,
  deliveryFee: 0,
  taxTotal: 0,
  grandTotal: 20,
);

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('orders filters fit a narrow screen without overflow', (
    tester,
  ) async {
    _setViewport(tester, 360);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderPageBody(
            orders: <AdminOrder>[_order()],
            search: '',
            onSearchChanged: (_) {},
            onChangeStatus: (_, _) {},
            onOpen: (_) {},
            onRefresh: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#1001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('orders count follows the panel language', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderPageBody(
            orders: <AdminOrder>[_order()],
            search: '',
            onSearchChanged: (_) {},
            onChangeStatus: (_, _) {},
            onOpen: (_) {},
            onRefresh: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(OrderSummaryMetricFormat.digits(S.ordersRowsLabel(1, 1, 1))),
      findsOneWidget,
    );
  });
}
