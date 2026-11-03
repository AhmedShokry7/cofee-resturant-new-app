// The cart page's load states, tested through the page.
//
// A cart is only known after a read — a device slot and, for a signed-in
// customer, a server round trip — so the page must not present "Your cart is
// empty" while that read is still running. The other half matters just as much:
// a customer who genuinely has nothing must not be left staring at a skeleton.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/cart/presentation/views/cart_page.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_card.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

import 'support/mock_product_repository.dart';

/// A catalogue that answers only when the test releases it, standing in for the
/// round trip a restored cart has to wait on.
class _SlowCatalog extends MockProductRepository {
  _SlowCatalog(this._release);

  final Completer<void> _release;

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) async {
    await _release.future;
    return super.getById(id, branchId: branchId);
  }
}

void main() {
  Future<CartCubit> pumpCart(
    WidgetTester tester,
    CatalogRepository catalog,
  ) async {
    tester.view.physicalSize = const Size(360, 690) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cubit = CartCubit(
      cartRepository: LocalCartRepository(),
      catalogRepository: catalog,
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cubit, child: const CartPage()),
      ),
    );
    await tester.pump();
    return cubit;
  }

  testWidgets('a cart still on its way is not announced as empty', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'cart_v1_guest': jsonEncode([
        {'productId': '1', 'quantity': 2},
      ]),
    });
    final release = Completer<void>();

    await pumpCart(tester, _SlowCatalog(release));

    expect(find.byType(CartLinesSkeleton), findsOneWidget);
    expect(find.text(S.cartEmpty), findsNothing);

    release.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CartLinesSkeleton), findsNothing);
    expect(find.byType(ProductCard), findsOneWidget);
    expect(find.text('Espresso'), findsOneWidget);
    expect(find.text(S.cartEmpty), findsNothing);
  });

  testWidgets('a cart that is really empty stops loading', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final cubit = await pumpCart(tester, const MockProductRepository());
    await cubit.settled;
    await tester.pumpAndSettle();

    expect(find.byType(CartLinesSkeleton), findsNothing);
    expect(find.text(S.cartEmpty), findsOneWidget);
  });
}
