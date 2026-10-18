import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';

import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';

void main() {
  test('adding a bundle creates one bundle cart line', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = MockProductRepository();
    final cubit = CartCubit(
      cartRepository: LocalCartRepository(),
      catalogRepository: repository,
    );
    await cubit.load();

    cubit.addBundle(
      bundleId: 'bundle-1',
      title: 'Bundle',
      image: 'assets/images/product.png',
      price: 100,
      components: const [
        CartBundleComponent(productId: '1', quantity: 2, unitPrice: 60),
        CartBundleComponent(productId: '2', quantity: 1, unitPrice: 40),
      ],
      quantity: 1,
    );

    expect(cubit.state.items, hasLength(1));
    expect(cubit.state.items.single.isBundle, isTrue);
    expect(cubit.state.items.single.product.name, 'Bundle');
    expect(cubit.state.items.single.total, 100);
    expect(cubit.state.items.single.bundleComponents, hasLength(2));

    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString('cart_v1_guest')!) as List;
    expect(stored, hasLength(1));
    expect(stored.single['isBundle'], isTrue);

    final restored = CartCubit(
      cartRepository: LocalCartRepository(),
      catalogRepository: repository,
    );
    await restored.load();
    expect(restored.state.items, hasLength(1));
    expect(restored.state.items.single.isBundle, isTrue);
    expect(restored.state.items.single.total, 100);

    await cubit.close();
    await restored.close();
  });

  test('bundle quantity changes update the bundle line', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = MockProductRepository();
    final cubit = CartCubit(
      cartRepository: LocalCartRepository(),
      catalogRepository: repository,
    );
    await cubit.load();

    cubit.addBundle(
      bundleId: 'bundle-1',
      title: 'Bundle',
      image: 'assets/images/product.png',
      price: 100,
      components: const [
        CartBundleComponent(productId: '1', quantity: 1, unitPrice: 100),
      ],
    );
    final lineId = cubit.state.items.single.lineId;
    cubit.incrementLine(lineId);
    expect(cubit.state.items.single.quantity, 2);
    expect(cubit.state.items.single.total, 200);

    await cubit.close();
  });
}