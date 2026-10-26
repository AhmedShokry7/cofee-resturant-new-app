import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_cards.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filtering.dart';

AdminOrder _order({
  String status = 'pending',
  String fulfillment = 'delivery',
}) {
  return AdminOrder(
    id: 'o1',
    orderNumber: '1001',
    customerName: 'Ahmed',
    fulfillmentType: fulfillment,
    status: status,
    paymentStatus: 'paid',
    subtotal: 100,
    discountTotal: 0,
    deliveryFee: 5,
    taxTotal: 0,
    grandTotal: 105,
    placedAt: DateTime(2026, 1, 2, 15, 30),
    items: const <AdminOrderItem>[],
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

  testWidgets('the card shows the number, the status and the total', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(OrderCard(order: _order())));

    expect(find.text('#1001'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Ahmed'), findsOneWidget);
    expect(find.text('105.00'), findsOneWidget);
    expect(find.textContaining('Delivery'), findsOneWidget);
  });

  testWidgets('the card speaks the language of the panel', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    await tester.pumpWidget(_wrap(OrderCard(order: _order())));

    expect(find.text(S.statusPending), findsOneWidget);
    expect(find.text('Pending'), findsNothing);
    expect(find.text(S.fulfillmentDelivery), findsOneWidget);
  });

  testWidgets('the card names a pickup order by its branch', (tester) async {
    final order = AdminOrder(
      id: 'o2',
      orderNumber: '1002',
      customerName: 'Sara',
      branchNameAr: 'ط§ظ„ظپط±ط¹ ط§ظ„ط±ط¦ظٹط³ظٹ',
      branchNameEn: 'Main branch',
      fulfillmentType: 'pickup',
      status: 'ready',
      paymentStatus: 'unpaid',
      subtotal: 20,
      discountTotal: 0,
      deliveryFee: 0,
      taxTotal: 0,
      grandTotal: 20,
    );
    await tester.pumpWidget(_wrap(OrderCard(order: order)));

    expect(find.textContaining('Main branch'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.textContaining(S.paymentStatusUnpaid), findsOneWidget);
  });

  test('the status filter narrows the list without a new query', () {
    final orders = <AdminOrder>[
      _order(status: 'pending'),
      _order(status: 'completed').copyWithStatus('completed'),
    ];

    final filtered = filterOrders(orders, status: 'pending');

    expect(filtered, hasLength(1));
    expect(filtered.single.status, 'pending');
  });
}

extension on AdminOrder {
  AdminOrder copyWithStatus(String status) {
    return AdminOrder(
      id: id,
      orderNumber: orderNumber,
      userId: userId,
      customerName: customerName,
      customerEmail: customerEmail,
      customerAvatarUrl: customerAvatarUrl,
      branchId: branchId,
      branchNameAr: branchNameAr,
      branchNameEn: branchNameEn,
      deliveryAddressSnapshot: deliveryAddressSnapshot,
      fulfillmentType: fulfillmentType,
      status: status,
      paymentStatus: paymentStatus,
      subtotal: subtotal,
      discountTotal: discountTotal,
      deliveryFee: deliveryFee,
      taxTotal: taxTotal,
      grandTotal: grandTotal,
      placedAt: placedAt,
      items: items,
    );
  }
}
