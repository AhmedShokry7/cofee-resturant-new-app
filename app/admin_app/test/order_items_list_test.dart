import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_items_list.dart';

AdminOrderItem _item({String? id}) {
  return AdminOrderItem(
    id: id,
    productId: 'p1',
    productNameEn: 'Latte',
    productNameAr: 'لاتيه',
    quantity: 2,
    unitPrice: 10,
    lineTotal: 20,
  );
}

AdminOrder _order({
  String status = 'pending',
  List<AdminOrderItem> items = const <AdminOrderItem>[],
}) {
  return AdminOrder(
    id: 'o1',
    orderNumber: '1001',
    customerName: 'Ahmed',
    fulfillmentType: 'delivery',
    status: status,
    paymentStatus: 'unpaid',
    subtotal: 20,
    discountTotal: 0,
    deliveryFee: 0,
    taxTotal: 0,
    grandTotal: 20,
    items: items,
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() {
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  tearDown(() {
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  testWidgets('an item without an identifier cannot be removed', (
    tester,
  ) async {
    var removed = false;
    await tester.pumpWidget(
      _wrap(
        OrderItemsList(
          order: _order(items: [_item()]),
          onRemoveItem: (_) => removed = true,
        ),
      ),
    );

    expect(find.text('Latte'), findsOneWidget);
    expect(find.text('2 \u00D7 10.00'), findsOneWidget);
    expect(find.text('20.00'), findsOneWidget);

    final button = tester.widget<IconButton>(
      find.descendant(
        of: find.byType(OrderItemsList),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(removed, isFalse);
  });

  testWidgets('a completed order never offers a removal', (tester) async {
    await tester.pumpWidget(
      _wrap(
        OrderItemsList(
          order: _order(
            status: 'completed',
            items: [_item(id: 'i1')],
          ),
          onRemoveItem: (_) {},
        ),
      ),
    );

    final button = tester.widget<IconButton>(
      find.descendant(
        of: find.byType(OrderItemsList),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('removal asks for a confirmation before it runs', (tester) async {
    var removed = false;
    await tester.pumpWidget(
      _wrap(
        OrderItemsList(
          order: _order(items: [_item(id: 'i1')]),
          onRemoveItem: (_) => removed = true,
        ),
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(OrderItemsList),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(S.removeItemConfirm), findsOneWidget);
    expect(removed, isFalse);

    await tester.tap(find.text(S.delete));
    await tester.pumpAndSettle();

    expect(removed, isTrue);
  });
}
