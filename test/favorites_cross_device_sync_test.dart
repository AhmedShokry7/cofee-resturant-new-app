import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'support/mock_product_repository.dart';

import 'support/fake_postgrest_server.dart';

/// Cross-device synchronisation of the favourites.
///
/// Two independent sessions share one server, the way two phones signed in
/// with the same account behave. The second session starts with an empty
/// device cache, so a heart it can show can only have come from the server.
void main() {
  late FakePostgrestServer server;

  setUp(() async {
    server = await FakePostgrestServer.start();
    server.users['customer.a@test.local'] = 'user-a';
    server.users['customer.b@test.local'] = 'user-b';
  });

  tearDown(() async => server.close());

  Future<SupabaseClient> signedIn(String email) async {
    final client = SupabaseClient(server.url, 'test-key');
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(email: email, password: 'secret');
    return client;
  }

  Future<FavoritesCubit> device(String email) async {
    final client = await signedIn(email);
    final cubit = FavoritesCubit(
      repository: MockProductRepository(),
      favorites: FavoritesRepositoryImpl(
        client: client,
        userIdProvider: () => client.auth.currentUser!.id,
      ),
    );
    addTearDown(cubit.close);
    await cubit.load();
    return cubit;
  }

  test('a favourite added on one device is stored on the server', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final first = await device('customer.a@test.local');

    await first.toggle('3');

    expect(server.favorites, hasLength(1));
    expect(server.favorites.values.single['product_id'], '3');
  });

  test('a favourite added on one device shows up on the other one', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final first = await device('customer.a@test.local');
    await first.toggle('3');

    // The second device starts with an empty device cache.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final second = await device('customer.a@test.local');

    expect(second.state.ids, contains('3'));
    expect(
      second.state.favoriteProducts.map((product) => product.name),
      ['Latte'],
    );
  });

  test('a favourite removed on one device disappears on the other one', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final first = await device('customer.a@test.local');
    await first.toggle('3');
    expect(server.favorites, hasLength(1));

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final second = await device('customer.a@test.local');
    expect(second.state.ids, contains('3'));

    await first.toggle('3');
    expect(server.favorites, isEmpty);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final third = await device('customer.a@test.local');
    expect(third.state.ids, isNot(contains('3')));
  });

  test('one account never sees the favourites of another', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final a = await device('customer.a@test.local');
    await a.toggle('3');

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final b = await device('customer.b@test.local');
    expect(b.state.ids, isEmpty);

    // B cannot write a row for A either.
    final client = await signedIn('customer.b@test.local');
    Object? error;
    try {
      await client.from('customer_favorites').insert({
        'user_id': 'user-a',
        'product_id': '3',
      });
    } catch (e) {
      error = e;
    }
    expect(error, isNotNull);
    expect(server.favorites, hasLength(1));
  });

  test(
    'a refused write is reported instead of being shown as a saved heart',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final first = await device('customer.a@test.local');

      server.failNextWriteWithStatus = 500;
      await first.toggle('3');

      expect(first.state.error, isNotNull);
      expect(server.favorites, isEmpty);
    },
  );
}
