import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
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

  test(
    'a bundle id survives persistence and restore, and a re-add replaces it',
    () async {
      SharedPreferences.setMockInitialValues({});

      final repository = MockProductRepository();
      final product = await repository.getById('1');
      final cubit = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: repository,
      );
      await cubit.load();

      // Two adds of the same product/note/options merge into one line; the
      // bundle id is deliberately not part of the merge identity, so the
      // latest write wins, matching the server's ON CONFLICT update.
      cubit.add(product!, bundleId: 'bundle-x');
      cubit.add(product, bundleId: 'bundle-y');

      expect(cubit.state.items, hasLength(1));
      expect(cubit.state.items.single.quantity, 2);
      expect(cubit.state.items.single.bundleId, 'bundle-y');

      final prefs = await SharedPreferences.getInstance();
      final stored = jsonDecode(prefs.getString('cart_v1_guest')!) as List;
      expect(stored.single['bundleId'], 'bundle-y');

      // A fresh cubit is rebuilt from device storage, so the bundle
      // membership must round-trip without the catalogue knowing about it.
      final restored = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: repository,
      );
      await restored.load();

      expect(restored.state.items.single.bundleId, 'bundle-y');
      expect(restored.state.items.single.quantity, 2);

      await cubit.close();
      await restored.close();
    },
  );

  test(
    'a failed guest-cart adoption preserves the guest slot',
    () async {
      SharedPreferences.setMockInitialValues({
        'cart_v1_guest': jsonEncode([
          {'productId': '1', 'quantity': 2},
        ]),
      });

      final cubit = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: _ThrowingCatalog(),
        userIdProvider: () => 'user-a',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final prefs = await SharedPreferences.getInstance();
      final stored = jsonDecode(prefs.getString('cart_v1_guest')!) as List;
      expect(stored, isNotEmpty);

    await cubit.close();
  },
  );

  test(
    'an unavailable product is preserved when loading under a branch',
    () async {
      SharedPreferences.setMockInitialValues({
        'cart_v1_guest': jsonEncode([
          {'productId': 'missing', 'quantity': 2, 'unitPrice': 10.0},
        ]),
      });

      final cubit = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: _UnavailableBranchCatalog(),
        branchId: 'branch-2',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.items.map((item) => item.product.id), ['missing']);
      expect(cubit.state.items.single.product.name, S.productUnavailable);

      await cubit.close();
    },
  );
}

class _ThrowingCatalog extends MockProductRepository {
  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = 100,
    int offset = 0,
  }) async {
    throw StateError('catalog down');
  }

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) async {
    throw StateError('catalog down');
  }
}

class _UnavailableBranchCatalog extends MockProductRepository {
  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = 100,
    int offset = 0,
  }) async {
    return const [];
  }

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) async {
    return null;
  }
}
