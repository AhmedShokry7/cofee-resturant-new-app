import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/mock_product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';

/// Counts catalogue reads and forwards the rest to the real offline catalogue,
/// so the assertions are about how often, not about content.
class _CountingCatalog implements CatalogRepository {
  _CountingCatalog([CatalogRepository? inner])
    : _inner = inner ?? MockProductRepository();

  final CatalogRepository _inner;

  int getProductsCalls = 0;

  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = 100,
    int offset = 0,
  }) {
    getProductsCalls++;
    return _inner.getProducts(
      branchId: branchId,
      categoryId: categoryId,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) =>
      _inner.getById(id, branchId: branchId);

  @override
  Future<ProductWithOptions?> getWithOptions(String id, {String? branchId}) =>
      _inner.getWithOptions(id, branchId: branchId);

  @override
  Future<Map<String, List<OptionGroup>>> getOptionsByProduct(
    List<String> productIds,
  ) => _inner.getOptionsByProduct(productIds);

  @override
  Future<List<ProductModel>> search(
    String query, {
    String? branchId,
    String? categoryId,
    String sort = 'relevance',
    int limit = 20,
    int offset = 0,
  }) => _inner.search(
    query,
    branchId: branchId,
    categoryId: categoryId,
    sort: sort,
    limit: limit,
    offset: offset,
  );

  @override
  Future<List<FeaturedProduct>> getFeatured({
    String? branchId,
    int limit = 10,
  }) => _inner.getFeatured(branchId: branchId, limit: limit);

  @override
  Future<List<BestSeller>> getBestSellers({
    String? branchId,
    Duration period = const Duration(days: 30),
    int limit = 10,
  }) => _inner.getBestSellers(
    branchId: branchId,
    period: period,
    limit: limit,
  );

  @override
  Future<ResolvedPrice?> resolvePrice(
    String productId, {
    String? branchId,
    List<String> optionValueIds = const [],
  }) => _inner.resolvePrice(
    productId,
    branchId: branchId,
    optionValueIds: optionValueIds,
  );

  @override
  Future<List<BannerModel>> getBanners({int limit = 20}) =>
      _inner.getBanners(limit: limit);

  @override
  Future<List<BundleModel>> getBundles({String? branchId, int limit = 20}) =>
      _inner.getBundles(branchId: branchId, limit: limit);

  @override
  Future<BundleModel?> getBundleById(String id) => _inner.getBundleById(id);

  @override
  Future<List<CategoryModel>> getCategories({bool includeInactive = false}) =>
      _inner.getCategories(includeInactive: includeInactive);

  @override
  Future<CategoryModel?> getCategoryById(String id) =>
      _inner.getCategoryById(id);

  @override
  Future<CategoryModel?> getCategoryBySlug(String slug) =>
      _inner.getCategoryBySlug(slug);

  @override
  Future<List<CategoryModel>> getCategoryChildren(String parentId) =>
      _inner.getCategoryChildren(parentId);
}

/// Counts the guest-id migration, the one write a favourites load performs, and
/// can hold it open so two loads provably overlap.
class _CountingFavorites implements FavoritesRepository {
  _CountingFavorites([FavoritesRepository? inner, this.gate])
    : _inner = inner ?? FavoritesRepositoryImpl();

  final FavoritesRepository _inner;
  final Future<void>? gate;

  int migrateCalls = 0;

  @override
  Future<void> migrateGuestIds() {
    migrateCalls++;
    final held = gate;
    if (held == null) return _inner.migrateGuestIds();
    return held.then((_) => _inner.migrateGuestIds());
  }

  @override
  Future<Set<String>> loadLocalIds() => _inner.loadLocalIds();

  @override
  Future<Set<String>> synchronizedIds(
    Set<String> localIds, {
    required Set<String> validProductIds,
  }) => _inner.synchronizedIds(
    localIds,
    validProductIds: validProductIds,
  );

  @override
  Future<void> addFavorite(String productId) => _inner.addFavorite(productId);

  @override
  Future<void> removeFavorite(String productId) =>
      _inner.removeFavorite(productId);
}

Future<void> _writeGuestCart(String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(CartCubit.storageKeyFor(null), value);
}

/// CartCubit exposes no loading flag, so poll until the constructor load lands.
Future<void> _settle(CartCubit cubit) async {
  for (var i = 0; i < 200; i++) {
    if (cubit.state.items.isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  group('cart initialises exactly once', () {
    test('the constructor reads the catalogue once, not twice', () async {
      SharedPreferences.setMockInitialValues({
        'cart_v1_guest': jsonEncode([
          {'productId': '1', 'quantity': 1},
        ]),
      });
      final catalog = _CountingCatalog();

      final cubit = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: catalog,
      );
      addTearDown(cubit.close);
      await _settle(cubit);

      expect(
        catalog.getProductsCalls,
        1,
        reason: 'one catalogue read restores the stored lines',
      );

      // An explicit reload still costs exactly one more read: nothing runs
      // twice behind the caller's back and nothing is repeated for free.
      await cubit.load();
      expect(catalog.getProductsCalls, 2);
    });

    test('an empty cart never reaches the catalogue', () async {
      SharedPreferences.setMockInitialValues({});
      final catalog = _CountingCatalog();

      final cubit = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: catalog,
      );
      addTearDown(cubit.close);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(catalog.getProductsCalls, 0);
      expect(cubit.state.items, isEmpty);
    });
  });

  group('guest adoption is not repeated', () {
    test('the guest cart is claimed exactly once per account', () async {
      SharedPreferences.setMockInitialValues({});
      await _writeGuestCart('[{"productId":"1","quantity":3}]');

      String? currentUser = 'user-a';
      final cubit = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
        userIdProvider: () => currentUser,
      );
      addTearDown(cubit.close);
      await _settle(cubit);

      expect(cubit.state.items.single.quantity, 3);

      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString(CartCubit.storageKeyFor(null))!),
        isEmpty,
        reason: 'the guest slot is emptied so a later sign-out starts empty',
      );

      // The lines now live under the account key, not the guest slot.
      currentUser = 'user-b';
      final other = CartCubit(
        cartRepository: LocalCartRepository(),
        catalogRepository: MockProductRepository(),
        userIdProvider: () => currentUser,
      );
      addTearDown(other.close);
      await other.load();
      expect(other.state.items, isEmpty);
    });

    test('overlapping favourites loads migrate the guest ids once', () async {
      SharedPreferences.setMockInitialValues({
        'favorites_v1_guest': jsonEncode(['1']),
      });
      final gate = Completer<void>();
      final favorites = _CountingFavorites(
        FavoritesRepositoryImpl(userIdProvider: () => 'user-a'),
        gate.future,
      );

      final cubit = FavoritesCubit(
        repository: MockProductRepository(),
        favorites: favorites,
      );
addTearDown(cubit.close);

      // Listen before either load can emit. The superseded constructor load is
      // discarded on purpose, so the second load owns the final state and its
      // emission is what settles here.
      final settled = cubit.stream.firstWhere((state) => !state.isLoading);

      // The constructor load is parked inside migrateGuestIds. Start a second
      // load so both sit inside that write at the same time.
      final second = cubit.load();
      await Future<void>.delayed(Duration.zero);
      expect(
        favorites.migrateCalls,
        1,
        reason: 'the guest slot may only be claimed by one load at a time',
      );

      gate.complete();
      await second;
      await settled;

      expect(favorites.migrateCalls, 1);
      expect(cubit.state.ids, contains('1'));

      // A later, separate load is still free to migrate: the guard covers
      // overlap only, it does not disable the step.
      await cubit.load();
      expect(favorites.migrateCalls, 2);
    });

    test('a fresh favourites load reads the catalogue once', () async {
      SharedPreferences.setMockInitialValues({});
      final catalog = _CountingCatalog();
      final cubit = FavoritesCubit(
        repository: catalog,
        favorites: FavoritesRepositoryImpl(),
      );
      addTearDown(cubit.close);

      await cubit.stream.firstWhere((state) => !state.isLoading);
      expect(catalog.getProductsCalls, 1);

      await cubit.load();
      expect(catalog.getProductsCalls, 2);
    });

    test('toggling still persists a single product', () async {
      SharedPreferences.setMockInitialValues({});
      final cubit = FavoritesCubit(
        repository: MockProductRepository(),
        favorites: FavoritesRepositoryImpl(),
      );
      addTearDown(cubit.close);
      await cubit.stream.firstWhere((state) => !state.isLoading);

      await cubit.toggle('2');
      expect(cubit.state.ids, {'2'});

      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('favorites_v1_guest')!), ['2']);
    });
  });
}