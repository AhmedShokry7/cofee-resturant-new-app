import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_payment_section.dart';

AdminOrder _order({
  String fulfillment = 'delivery',
  String paymentStatus = 'paid',
}) {
  return AdminOrder(
    id: 'o1',
    orderNumber: '1001',
    customerName: 'Ahmed',
    fulfillmentType: fulfillment,
    status: 'confirmed',
    paymentStatus: paymentStatus,
    subtotal: 100,
    discountTotal: 10,
    deliveryFee: 5,
    taxTotal: 3,
    grandTotal: 98,
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

  testWidgets('the section shows the authoritative totals of the order', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(OrderPaymentSection(order: _order())));

    expect(find.text(S.subtotal), findsOneWidget);
    expect(find.text('100.00'), findsOneWidget);
    expect(find.text(S.discount), findsOneWidget);
    expect(find.text(S.deliveryFee), findsOneWidget);
    expect(find.text(S.tax), findsOneWidget);
    expect(find.text(S.grandTotal), findsOneWidget);
    expect(find.text('98.00'), findsOneWidget);
    expect(find.text(S.paymentStatusPaid), findsOneWidget);
  });

  testWidgets('a pickup order does not show a delivery fee', (tester) async {
    await tester.pumpWidget(
      _wrap(OrderPaymentSection(order: _order(fulfillment: 'pickup'))),
    );

    expect(find.text(S.deliveryFee), findsNothing);
    expect(find.text(S.subtotal), findsOneWidget);
  });

  testWidgets('the payment method only appears when the backend sent one', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(OrderPaymentSection(order: _order())));
    expect(find.text(S.paymentMethod), findsNothing);

    await tester.pumpWidget(
      _wrap(
        OrderPaymentSection(
          order: _order(),
          paymentMethodLabel: S.paymentMethodCash,
        ),
      ),
    );
    expect(find.text(S.paymentMethod), findsOneWidget);
    expect(find.text(S.paymentMethodCash), findsOneWidget);
  });

  testWidgets('payment status is translated with the panel', (tester) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    await tester.pumpWidget(
      _wrap(OrderPaymentSection(order: _order(paymentStatus: 'failed'))),
    );

    expect(find.text(S.paymentStatusFailed), findsOneWidget);
    expect(find.text('Failed'), findsNothing);
  });
}
