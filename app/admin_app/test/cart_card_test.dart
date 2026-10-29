import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/carts/data/models/admin_cart.dart';
import 'package:admin_app/features/carts/presentation/widgets/cart_details_dialog.dart';
import 'package:admin_app/features/carts/presentation/widgets/cart_records.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

AdminCart _cart({String status = 'active'}) {
  return AdminCart(
    id: 'c1',
    customerName: 'Ahmed',
    customerEmail: 'ahmed@example.com',
    branchId: 'b1',
    branchNameAr: 'الفرع الرئيسي',
    branchNameEn: 'Main branch',
    status: status,
    total: 45.5,
    updatedAt: DateTime(2026, 2, 3, 10, 15),
    items: const <AdminCartItem>[
      AdminCartItem(
        id: 'i1',
        productId: 'p1',
        productNameEn: 'Latte',
        productNameAr: 'لاتيه',
        quantity: 2,
        unitPrice: 10,
        lineTotal: 20,
      ),
      AdminCartItem(
        id: 'i2',
        productId: 'p2',
        productNameEn: 'Mocha',
        productNameAr: 'موكا',
        quantity: 1,
        unitPrice: 25.5,
        lineTotal: 25.5,
      ),
    ],
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

  testWidgets('the outer card only shows name, count, total and status', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(CartCard(cart: _cart())));

    expect(find.text('Ahmed'), findsOneWidget);
    expect(find.text('45.50'), findsOneWidget);
    expect(find.byType(CurrencyIcon), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text(S.cartStatusActive), findsOneWidget);
  });

  testWidgets('the outer card never shows the branch or the products', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(CartCard(cart: _cart())));

    // The branch is valid cart data, but it belongs to the details view.
    expect(find.textContaining('Main branch'), findsNothing);
    expect(find.textContaining('Latte'), findsNothing);
    expect(find.textContaining('Mocha'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(CartCard),
        matching: find.byType(ClipRRect),
      ),
      findsNothing,
      reason: 'no product pictures belong on the outer card',
    );
  });

  testWidgets('the outer card speaks the language of the panel', (
    tester,
  ) async {
    AppLocale.instance.debugSet(AppLanguage.arabic);
    await tester.pumpWidget(_wrap(CartCard(cart: _cart())));

    expect(find.text(S.cartStatusActive), findsOneWidget);
    expect(find.text('Active'), findsNothing);
    expect(find.text(S.cartItemsCount(2)), findsOneWidget);
  });

  testWidgets('an abandoned cart is shown as abandoned', (tester) async {
    await tester.pumpWidget(_wrap(CartCard(cart: _cart(status: 'abandoned'))));
    expect(find.text(S.cartStatusAbandoned), findsOneWidget);
  });

  testWidgets('the details view is a cart and keeps the branch', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(CartDetailsDialog(cart: _cart())));

    expect(find.text(S.cartDetailsTitle), findsOneWidget);
    expect(find.textContaining('Order details'), findsNothing);
    // The branch association is valid and stays visible in the details.
    expect(find.textContaining('Main branch'), findsOneWidget);
    expect(find.textContaining('Latte'), findsOneWidget);
    expect(find.text('45.50'), findsOneWidget);
    expect(find.byType(CurrencyIcon), findsWidgets);
    expect(find.textContaining(S.updatedAt), findsOneWidget);
    // No order actions on a cart.
    expect(find.text(S.changeStatus), findsNothing);
  });
}
