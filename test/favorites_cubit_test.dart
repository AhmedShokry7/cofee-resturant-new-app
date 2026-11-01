import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';

import 'support/mock_product_repository.dart';

Future<FavoritesCubit> _readyCubit() async {
  final cubit = FavoritesCubit(
    repository: MockProductRepository(),
    favorites: FavoritesRepositoryImpl(),
  );
  await cubit.stream.firstWhere((state) => !state.isLoading);
  return cubit;
}

void main() {
  test('stored favourite ids resolve to catalogue rows', () async {
    SharedPreferences.setMockInitialValues({
      'favorites_v1_guest': jsonEncode(['1', 'missing-product']),
    });

    final cubit = await _readyCubit();
    expect(cubit.state.favoriteProducts.map((product) => product.name), [
      'Espresso',
    ]);
    // An id that no longer exists is not shown, but its heart stays set.
    expect(cubit.state.ids, {'1', 'missing-product'});
    await cubit.close();
  });

  test('an unknown product cannot gain a heart', () async {
    SharedPreferences.setMockInitialValues({});

    final cubit = await _readyCubit();
    await cubit.toggle('missing-product');

    expect(cubit.state.ids, isEmpty);
    expect(cubit.state.favoriteProducts, isEmpty);
    await cubit.close();
  });

  test('guest favourite ids stay on the device without a session', () async {
    SharedPreferences.setMockInitialValues({});

    final cubit = await _readyCubit();
    await cubit.toggle('2');

    expect(cubit.state.ids, {'2'});
    expect(cubit.state.favoriteProducts.map((product) => product.name), [
      'Cappuccino',
    ]);

    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('favorites_v1_guest')!), ['2']);
    await cubit.close();
  });

  test('guest storage adds and removes ids without a session', () async {
    SharedPreferences.setMockInitialValues({});
    const repository = FavoritesRepositoryImpl();

    await repository.addFavorite('1');
    expect(await repository.loadLocalIds(), {'1'});

    await repository.removeFavorite('1');
    expect(await repository.loadLocalIds(), isEmpty);
  });
}
