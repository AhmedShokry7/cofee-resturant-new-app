import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/features/cart/data/model/cart_line.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';

import 'support/mock_product_repository.dart';

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

  test(
    'a personal bundle stays one cart line but prices regular components',
    () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
      );
      await cubit.load();

      cubit.addPersonalBundle(
        customerBundleId: 'saved-1',
        title: 'My morning set',
        image: 'assets/images/product.png',
        price: 45,
        components: const [
          CartBundleComponent(productId: '1', quantity: 2, unitPrice: 15),
          CartBundleComponent(productId: '2', quantity: 1, unitPrice: 15),
        ],
      );

      expect(cubit.state.items, hasLength(1));
      final personalBundle = cubit.state.items.single;
      expect(personalBundle.isBundle, isTrue);
      expect(personalBundle.customerBundleId, 'saved-1');
      expect(personalBundle.bundleId, isNull);
      expect(personalBundle.total, 45);

      final serverLines = serverLinesForItems(cubit.state.items);
      expect(serverLines, hasLength(2));
      expect(serverLines.map((line) => line.productId), ['1', '2']);
      expect(serverLines.map((line) => line.quantity), [2, 1]);
      expect(serverLines.every((line) => line.bundleId == null), isTrue);

      final prefs = await SharedPreferences.getInstance();
      final entry =
          (jsonDecode(prefs.getString('cart_v1_guest')!) as List).single;
      expect(entry['customerBundleId'], 'saved-1');

      final restored = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
      );
      await restored.load();
      expect(restored.state.items, hasLength(1));
      expect(restored.state.items.single.customerBundleId, 'saved-1');
      expect(restored.state.items.single.product.name, 'My morning set');

      await cubit.close();
      await restored.close();
    },
  );

  test('server component rows restore the personal bundle wrapper', () {
    final merged = mergeServerLines(
      const [
        CartLine(productId: '1', quantity: 3, unitPrice: 11),
        CartLine(productId: '2', quantity: 2, unitPrice: 5),
      ],
      const [
        {
          'productId': 'personal-bundle:saved-1',
          'customerBundleId': 'saved-1',
          'isBundle': true,
          'quantity': 2,
          'bundleTitle': 'My set',
          'bundleComponents': [
            {'productId': '1', 'quantity': 1, 'unitPrice': 10},
            {'productId': '2', 'quantity': 1, 'unitPrice': 5},
          ],
        },
      ],
    );

    final bundle = merged.firstWhere((entry) => entry['isBundle'] == true);
    expect(bundle['customerBundleId'], 'saved-1');
    expect(bundle['quantity'], 2);
    expect(bundle['unitPrice'], 16);
    final standalone = merged.singleWhere((entry) => entry['isBundle'] != true);
    expect(standalone['productId'], '1');
    expect(standalone['quantity'], 1);
  });
}
