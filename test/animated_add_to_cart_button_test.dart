import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

import 'support/mock_product_repository.dart';

import 'package:new_coffee/shared/widgets/animated_add_to_cart_button.dart';

Future<ProductModel> _product() async =>
    (await MockProductRepository().getProducts()).first;

CartCubit _cart() => CartCubit(
  cartRepository: LocalCartRepository(),
  catalogRepository: MockProductRepository(),
);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('idle label becomes Adding then Added, with no SnackBar', (
    tester,
  ) async {
    final cart = _cart();
    addTearDown(cart.close);
    final product = await _product();

    await tester.pumpWidget(
      _wrap(
        AnimatedAddToCartButton(
          label: S.addToCart,
          onAdd: () async => cart.add(product),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(S.addToCart), findsOneWidget);

    await tester.tap(find.byType(AnimatedAddToCartButton));
    await tester.pump();
    expect(find.text(S.adding), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text(S.added), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(cart.state.count, 1);

    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();
    expect(find.text(S.addToCart), findsOneWidget);
  });

  testWidgets('repeated taps while in flight add the product only once', (
    tester,
  ) async {
    final cart = _cart();
    addTearDown(cart.close);
    final product = await _product();

    await tester.pumpWidget(
      _wrap(
        AnimatedAddToCartButton(
          label: S.addToCart,
          onAdd: () async => cart.add(product),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(AnimatedAddToCartButton));
    await tester.pump();
    await tester.tap(find.byType(AnimatedAddToCartButton));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    expect(cart.state.count, 1);
  });

  testWidgets('a failed add restores idle and reports through a SnackBar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AnimatedAddToCartButton(
          label: S.addToCart,
          onAdd: () async => throw StateError('boom'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(AnimatedAddToCartButton));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(S.failedToAddToCart), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.text(S.addToCart), findsOneWidget);

    // Let the SnackBar's own timer finish so the test has no pending timers.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('compact icon button shows a success check without a SnackBar', (
    tester,
  ) async {
    final cart = _cart();
    addTearDown(cart.close);
    final product = await _product();

    await tester.pumpWidget(
      _wrap(AnimatedAddToCartIconButton(onAdd: () async => cart.add(product))),
    );
    await tester.pump();

    await tester.tap(find.byType(AnimatedAddToCartIconButton));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    expect(cart.state.count, 1);
    expect(find.byType(SnackBar), findsNothing);
  });
}
