import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/favorites/presentation/views/favorites_page.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

import 'support/mock_product_repository.dart';

/// Holds both id reads open until the test says so.
///
/// The log is the assertion: a cubit that awaited the device slot before
/// issuing the server read would record `local-end` between the two starts.
class _GatedFavorites implements FavoritesRepository {
  _GatedFavorites(this._inner);

  final FavoritesRepository _inner;
  final Completer<void> release = Completer<void>();
  final List<String> log = [];

  Future<T> _gated<T>(String name, Future<T> Function() body) async {
    log.add('$name-start');
    await release.future;
    final value = await body();
    log.add('$name-end');
    return value;
  }

  @override
  Future<Set<String>> loadLocalIds() => _gated('local', _inner.loadLocalIds);

  @override
  Future<Set<String>> loadRemoteIds() => _gated('remote', _inner.loadRemoteIds);

  @override
  Future<void> synchronize({
    required Set<String> localIds,
    required Set<String> remoteIds,
    required Set<String> validProductIds,
  }) async {
    log.add('push-start');
    await release.future;
    await _inner.synchronize(
      localIds: localIds,
      remoteIds: remoteIds,
      validProductIds: validProductIds,
    );
    log.add('push-end');
  }

  @override
  Future<void> addFavorite(String productId) => _inner.addFavorite(productId);

  @override
  Future<void> removeFavorite(String productId) =>
      _inner.removeFavorite(productId);

  @override
  Future<void> migrateGuestIds() => _inner.migrateGuestIds();
}

/// A catalogue page that stops after one row, like a truncated read.
class _OneRowPageCatalog extends MockProductRepository {
  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = CatalogLimits.products,
    int offset = 0,
  }) async {
    pageReads++;
    final products = await super.getProducts(
      branchId: branchId,
      categoryId: categoryId,
      limit: limit,
      offset: offset,
    );
    return products.isEmpty ? products : [products.first];
  }

  int pageReads = 0;
}

class _FailingCatalog extends MockProductRepository {
  @override
  Future<ProductModel?> getById(String id, {String? branchId}) async {
    throw StateError('catalogue unreachable');
  }

  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = CatalogLimits.products,
    int offset = 0,
  }) async => throw StateError('catalogue unreachable');
}

/// Fails the mirror, so the sync error is the only thing the load produces.
///
/// [gate] holds the failure back until the test says so: a widget test needs
/// the error to land after the page subscribed, not during the pump that built
/// it, or the listener never sees a change.
class _RefusingSyncFavorites implements FavoritesRepository {
  _RefusingSyncFavorites(this._ids, {this.gate});

  final Set<String> _ids;
  final Future<void>? gate;

  int syncAttempts = 0;

  @override
  Future<Set<String>> loadLocalIds() async => _ids;

  @override
  Future<Set<String>> loadRemoteIds() async => const {};

  @override
  Future<void> synchronize({
    required Set<String> localIds,
    required Set<String> remoteIds,
    required Set<String> validProductIds,
  }) async {
    syncAttempts++;
    await gate;
    throw StateError('sync refused');
  }

  @override
  Future<void> addFavorite(String productId) async {}

  @override
  Future<void> removeFavorite(String productId) async {}

  @override
  Future<void> migrateGuestIds() async {}
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('favourites load shape', () {
    test('the device hearts and the server hearts are read together', () async {
      SharedPreferences.setMockInitialValues({
        'favorites_v1_guest': jsonEncode(['1']),
      });
      final favorites = _GatedFavorites(FavoritesRepositoryImpl());
      final cubit = FavoritesCubit(
        repository: MockProductRepository(),
        favorites: favorites,
      );
      addTearDown(cubit.close);

      // The constructor load is parked inside the two id reads.
      await Future<void>.delayed(Duration.zero);
      expect(
        favorites.log,
        containsAllInOrder(['local-start', 'remote-start']),
        reason: 'the server read must be issued while the device read is open',
      );

      favorites.release.complete();
      await cubit.stream.firstWhere((state) => !state.isLoading);
      expect(
        favorites.log.indexOf('remote-start'),
        lessThan(favorites.log.indexOf('local-end')),
      );
      expect(cubit.state.ids, {'1'});
    });

    test('a heart outside the catalogue page still shows', () async {
      SharedPreferences.setMockInitialValues({
        'favorites_v1_guest': jsonEncode(['1', '2', '3']),
      });
      // The page returns one row and the load still lists three hearts: the
      // rows come from the ids themselves, not from whatever a page carried.
      final catalog = _OneRowPageCatalog();
      final cubit = FavoritesCubit(
        repository: catalog,
        favorites: FavoritesRepositoryImpl(),
      );
      addTearDown(cubit.close);
      await cubit.stream.firstWhere((state) => !state.isLoading);

      expect(cubit.state.favoriteProducts.map((p) => p.name), [
        'Espresso',
        'Cappuccino',
        'Latte',
      ]);
      expect(catalog.pageReads, 0, reason: 'no page is read at all');
    });

    test('a failed mirror keeps the list and reports the failure', () async {
      SharedPreferences.setMockInitialValues({});
      final favorites = _RefusingSyncFavorites({'1'});
      final cubit = FavoritesCubit(
        repository: MockProductRepository(),
        favorites: favorites,
      );
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      for (var i = 0; i < 20 && cubit.state.error == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      expect(cubit.state.favoriteProducts.map((p) => p.name), [
        'Espresso',
      ], reason: 'the hearts the customer already has stay on screen');
      expect(cubit.state.error, S.favoritesSyncFailed);
      expect(favorites.syncAttempts, 1);
    });
  });

  group('favourites page states', () {
    Future<void> pumpPage(
      WidgetTester tester,
      FavoritesCubit cubit, {
      CatalogRepository? cartCatalog,
    }) async {
      tester.view.physicalSize = const Size(360, 690) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cart = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: cartCatalog ?? MockProductRepository(),
      );
      addTearDown(cart.close);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cart),
              BlocProvider.value(value: cubit),
            ],
            child: const FavoritesPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    /// The snack bar hides itself on a timer; a test that leaves it running
    /// ends with a pending timer.
    Future<void> expireSnackBar(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();
    }

    testWidgets('a failed read is not shown as an empty list', (tester) async {
      SharedPreferences.setMockInitialValues({
        'favorites_v1_guest': jsonEncode(['1']),
      });
      final cubit = FavoritesCubit(
        repository: _FailingCatalog(),
        favorites: FavoritesRepositoryImpl(),
      );
      addTearDown(cubit.close);

      await pumpPage(tester, cubit);

      expect(find.text(S.noFavorites), findsNothing);
      expect(find.text(S.couldNotLoadFavorites), findsOneWidget);
    });

    testWidgets('a customer with no hearts sees the empty list', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final cubit = FavoritesCubit(
        repository: MockProductRepository(),
        favorites: FavoritesRepositoryImpl(),
      );
      addTearDown(cubit.close);

      await pumpPage(tester, cubit);

      expect(find.text(S.noFavorites), findsOneWidget);
      expect(find.text(S.couldNotLoadFavorites), findsNothing);
    });

    testWidgets('a heart the server refused is announced', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final catalog = MockProductRepository();
      final gate = Completer<void>();
      final cubit = FavoritesCubit(
        repository: catalog,
        favorites: _RefusingSyncFavorites({'1'}, gate: gate.future),
      );
      addTearDown(cubit.close);

      await pumpPage(tester, cubit, cartCatalog: catalog);
      // The mirror fails once the page is listening.
      gate.complete();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Espresso'), findsWidgets);
      expect(find.text(S.favoritesSyncFailed), findsOneWidget);

      await expireSnackBar(tester);
    });
  });
}
