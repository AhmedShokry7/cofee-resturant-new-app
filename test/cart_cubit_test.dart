import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';

void main() {
  test(
    'stored cart ids resolve against the repository, not the old menu',
    () async {
      SharedPreferences.setMockInitialValues({
        'cart_v1_guest': jsonEncode([
          {
            'productId': '1',
            'quantity': 2,
            'note': 'Large',
            'optionValueIds': ['large'],
            'unitPrice': 35.0,
          },
          {'productId': 'missing-product', 'quantity': 1},
        ]),
      });

      final cubit = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
      );
      await cubit.load();

      expect(cubit.state.items.map((item) => item.product.id), ['1']);
      expect(cubit.state.items.single.optionValueIds, ['large']);
      expect(cubit.state.items.single.note, 'Large');
      expect(cubit.state.total, 70);
      await cubit.close();
    },
  );

  test(
    'the same variant merges, while different options stay separate',
    () async {
      SharedPreferences.setMockInitialValues({});

      final repository = MockProductRepository();
      final product = await repository.getById('1');
      final cubit = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: repository,
      );
      await cubit.load();

      cubit.add(product!, note: 'Large', optionValueIds: ['b', 'a']);
      cubit.add(product, note: 'Large', optionValueIds: ['a', 'b']);
      cubit.add(product, note: 'Large', optionValueIds: ['a']);

      expect(cubit.state.items.map((item) => item.quantity), [2, 1]);
      expect(cubit.state.items.map((item) => item.optionValueIds), [
        ['a', 'b'],
        ['a'],
      ]);

      cubit.decrementLine(cubit.state.items.first.lineId);
      expect(cubit.state.items.first.quantity, 1);

      final prefs = await SharedPreferences.getInstance();
      final stored = jsonDecode(prefs.getString('cart_v1_guest')!) as List;
      expect(stored.first['optionValueIds'], ['a', 'b']);
      await cubit.close();
    },
  );
}
