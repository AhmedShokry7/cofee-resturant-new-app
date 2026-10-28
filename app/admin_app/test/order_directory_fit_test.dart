import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_directory.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filter_values.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_table_row.dart';

/// ثلاثون طلبًا برقم فريد لكل صف، فيُقرأ عدد الصفوف المطبوعة من الجدول نفسه.
List<AdminOrder> _orders(int count) => [
  for (var index = 1; index <= count; index++)
    AdminOrder(
      id: 'o$index',
      orderNumber: '2${index.toString().padLeft(3, '0')}',
      customerName: 'Customer $index',
      fulfillmentType: 'delivery',
      status: 'preparing',
      paymentStatus: 'paid',
      subtotal: 20,
      discountTotal: 0,
      deliveryFee: 0,
      taxTotal: 0,
      grandTotal: 20,
    ),
];

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double height,
  required List<AdminOrder> orders,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OrderDirectory(
          orders: orders,
          branches: const [],
          search: '',
          onSearchChanged: (_) {},
          filters: const OrderFilterValues(),
          onFiltersChanged: (_) {},
          onChangeStatus: (_, _) {},
          onOpen: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// عدد الصفوف المطبوعة في الجدول الآن.
int _rows(WidgetTester tester) =>
    tester.widgetList<OrderTableRow>(find.byType(OrderTableRow)).length;

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('a tall window prints more rows instead of leaving them blank', (
    tester,
  ) async {
    await _pump(tester, width: 1400, height: 1000, orders: _orders(30));

    // الشاشة المكتبية كانت تطبع خمسة وتترك الباقي بياضًا يقرأه الأدمن كأن
    // الطلبات انتهت؛ الصفوف الآن تُقاس من مساحة الجدول.
    expect(tester.takeException(), isNull);
    expect(_rows(tester), greaterThan(5));
    expect(find.text('#2001'), findsOneWidget);
  });

  testWidgets('a shorter window prints fewer rows from the same orders', (
    tester,
  ) async {
    await _pump(tester, width: 1400, height: 1000, orders: _orders(30));
    final tall = _rows(tester);
    await _pump(tester, width: 1400, height: 620, orders: _orders(30));

    expect(_rows(tester), lessThan(tall));
    // القاع خمسة: نافذة قصيرة تمرّ عموديًا خير من صفحة من صفّين.
    expect(_rows(tester), greaterThanOrEqualTo(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the footer counts the rows the screen actually fits', (
    tester,
  ) async {
    await _pump(tester, width: 1400, height: 900, orders: _orders(30));
    final rows = _rows(tester);
    expect(rows, inInclusiveRange(6, 20));

    expect(
      find.text(S.ordersRowsLabel(1, rows, 30)),
      findsOneWidget,
      reason: 'the range must read the fitted page, not a fixed five',
    );

    await tester.tap(find.byTooltip(S.nextPage));
    await tester.pumpAndSettle();

    expect(find.text('#2001'), findsNothing);
    expect(
      find.text('#2${(rows + 1).toString().padLeft(3, '0')}'),
      findsOneWidget,
    );
    expect(_rows(tester), lessThanOrEqualTo(rows));
  });
}
