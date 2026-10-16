import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';

/// Per-customer isolation for carts and favourites.
///
/// Device storage is namespaced per account, so two customers sharing one
/// device never see each other's lines or hearts. A guest list is adopted
/// into the account once, on the first load after sign-in.
void main() {
  test('storage keys differ per account', () {
    expect(CartCubit.storageKeyFor(null), 'cart_v1_guest');
    expect(CartCubit.storageKeyFor('user-a'), 'cart_v1_user-a');
    expect(FavoritesRepositoryImpl.storageKeyFor(null), 'favorites_v1_guest');
    expect(
      FavoritesRepositoryImpl.storageKeyFor('user-a'),
      'favorites_v1_user-a',
    );
  });

  test('one account never sees another account favourites', () async {
    SharedPreferences.setMockInitialValues({});
    String? currentUser;
    FavoritesRepositoryImpl repo() =>
        FavoritesRepositoryImpl(userIdProvider: () => currentUser);

    currentUser = 'user-a';
    await repo().addFavorite('p1');
    expect(await repo().loadLocalIds(), {'p1'});

    currentUser = 'user-b';
    expect(await repo().loadLocalIds(), isEmpty);

    currentUser = null;
    expect(await repo().loadLocalIds(), isEmpty);

    currentUser = 'user-a';
    expect(await repo().loadLocalIds(), {'p1'});
  });

  test('guest hearts are adopted once on sign-in, then cleared', () async {
    SharedPreferences.setMockInitialValues({});
    String? currentUser;
    FavoritesRepositoryImpl repo() =>
        FavoritesRepositoryImpl(userIdProvider: () => currentUser);

    await repo().addFavorite('p9');
    expect(await repo().loadLocalIds(), {'p9'});

    currentUser = 'user-a';
    await repo().migrateGuestIds();
    expect(await repo().loadLocalIds(), {'p9'});

    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('favorites_v1_guest')!), isEmpty);

    // A second run is a no-op: nothing is duplicated or lost.
    await repo().migrateGuestIds();
    expect(await repo().loadLocalIds(), {'p9'});
  });

  test(
    'guest cart is adopted into an empty account cart, accounts stay isolated',
    () async {
      SharedPreferences.setMockInitialValues({});
      String? currentUser;
      CartCubit cubit() => CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
        userIdProvider: () => currentUser,
      );

      const product = ProductModel(
        id: '1',
        name: 'Espresso',
        category: 'Hot Coffee',
        description: 'd',
        price: 25,
        image: 'x',
      );

      // Guest shops while signed out.
      final guest = cubit();
      guest.add(product, quantity: 2);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // user-b signs in with an empty account: takes over the guest cart.
      currentUser = 'user-b';
      final b = cubit();
      await b.load();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(b.state.items.map((item) => item.product.id), ['1']);
      expect(b.state.items.single.quantity, 2);

      // The guest slot is cleared: a later sign-out starts empty.
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('cart_v1_guest')!), isEmpty);

      // user-a sees nothing of user-b.
      currentUser = 'user-a';
      final a = cubit();
      await a.load();
      expect(a.state.items, isEmpty);

      await guest.close();
      await b.close();
      await a.close();
    },
  );
}
