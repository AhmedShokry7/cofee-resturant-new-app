// Regression tests for the Categories page initial empty-state flicker.
//
// The Cubit used to emit the categories on their own with `isLoading: false`
// while the products and bundles requests were still in flight. The page then
// held a non-empty category list with zero products and rendered the "no
// products" empty state until the second batch landed.
//
// These tests pin the four states the page has to keep apart: loading,
// loaded-with-data, loaded-empty, and failed.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/categories/presentation/views/categories_page.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

import 'support/mock_product_repository.dart';

import 'package:new_coffee/features/menu/presentation/views/widgets/products_grid_view.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/shimmer/page_skeletons.dart';

/// Catalog whose three queries are resolved by the test, so the page can be
/// inspected at the exact moment the categories arrive but products have not.
class _ControlledCatalog extends MockProductRepository {
  _ControlledCatalog({
    this.categoriesResult = const [],
    this.productsResult = const [],
    this.failWith,
  });

  final List<CategoryModel> categoriesResult;
  final List<ProductModel> productsResult;

  /// When set, every query fails with this error.
  final Object? failWith;

  final Completer<List<CategoryModel>> categoriesGate = Completer();
  final Completer<List<ProductModel>> productsGate = Completer();
  final Completer<List<BundleModel>> bundlesGate = Completer();

  int categoryCalls = 0;
  int productCalls = 0;
  int bundleCalls = 0;

  @override
  Future<List<CategoryModel>> getCategories({
    bool includeInactive = false,
  }) async {
    categoryCalls++;
    if (failWith != null) throw failWith!;
    return categoriesGate.future.then((_) => categoriesResult);
  }

  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = 100,
    int offset = 0,
  }) async {
    productCalls++;
    if (failWith != null) throw failWith!;
    return productsGate.future.then((_) => productsResult);
  }

  @override
  Future<List<BundleModel>> getBundles({
    String? branchId,
    int limit = 20,
  }) async {
    bundleCalls++;
    if (failWith != null) throw failWith!;
    return bundlesGate.future.then((_) => const <BundleModel>[]);
  }
}

const _coffee = CategoryModel(
  id: 'cat-coffee',
  slug: 'coffee',
  nameEn: 'Coffee',
  nameAr: 'قهوة',
  icon: AppIcons.coffeeHot,
);

const _latte = ProductModel(
  id: 'prod-latte',
  name: 'Latte',
  price: 14,
  image: '',
  categoryId: 'cat-coffee',
);

Future<void> _pumpPage(
  WidgetTester tester,
  CategoriesCubit cubit,
  _ControlledCatalog catalog,
) async {
  tester.view.physicalSize = const Size(360, 800) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // ProductCard reads CartCubit when tapped and ProductFavoriteButton watches
  // FavoritesCubit; the page needs both present even though this suite never
  // taps a card.
  final cart = CartCubit(
    cartRepository: LocalCartRepository(),
    catalogRepository: catalog,
  );
  addTearDown(cart.close);
  final favorites = FavoritesCubit(
    repository: catalog,
    favorites: FavoritesRepositoryImpl(userIdProvider: () => null),
  );
  addTearDown(favorites.close);

  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<CategoriesCubit>.value(value: cubit),
          BlocProvider<CartCubit>.value(value: cart),
          BlocProvider<FavoritesCubit>.value(value: favorites),
        ],
        child: const CategoriesPage(),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'cold entry shows the skeleton and never an empty state before products land',
    (tester) async {
      final catalog = _ControlledCatalog(
        categoriesResult: const [_coffee],
        productsResult: const [_latte],
      );
      final cubit = CategoriesCubit(repository: catalog);
      addTearDown(cubit.close);

      await _pumpPage(tester, cubit, catalog);
      await tester.pump();

      // First frame: nothing has been requested yet.
      expect(find.byType(CategoriesLoadingView), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);

      // The regression window: categories are in, products are still pending.
      catalog.categoriesGate.complete(catalog.categoriesResult);
      await tester.pump();
      await tester.pump();

      expect(
        find.byType(CategoriesLoadingView),
        findsOneWidget,
        reason: 'the load is not finished while products are in flight',
      );
      expect(
        find.byType(EmptyState),
        findsNothing,
        reason: 'an empty state before data arrives is the reported flicker',
      );
      expect(find.text(S.noProductsYet), findsNothing);
      expect(find.text(S.noCategories), findsNothing);

      // Now let the rest of the batch finish.
      catalog.productsGate.complete(catalog.productsResult);
      catalog.bundlesGate.complete(const []);
      await tester.pump();
      await tester.pump();

      expect(find.byType(EmptyState), findsNothing);
      expect(find.byType(ProductsGridView), findsOneWidget);
    },
  );

  testWidgets('a successful empty response shows the empty state', (
    tester,
  ) async {
    final catalog = _ControlledCatalog();
    final cubit = CategoriesCubit(repository: catalog);
    addTearDown(cubit.close);

    await _pumpPage(tester, cubit, catalog);
    await tester.pump();
    expect(find.byType(CategoriesLoadingView), findsOneWidget);

    catalog
      ..categoriesGate.complete(catalog.categoriesResult)
      ..productsGate.complete(catalog.productsResult)
      ..bundlesGate.complete(const []);
    await tester.pump();
    await tester.pump();

    expect(find.byType(CategoriesLoadingView), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text(S.noCategories), findsOneWidget);
  });

  testWidgets(
    'a category with no products shows the empty state only after load',
    (tester) async {
      final catalog = _ControlledCatalog(
        categoriesResult: const [_coffee],
        productsResult: const [],
      );
      final cubit = CategoriesCubit(repository: catalog);
      addTearDown(cubit.close);

      await _pumpPage(tester, cubit, catalog);
      await tester.pump();

      catalog
        ..categoriesGate.complete(catalog.categoriesResult)
        ..productsGate.complete(catalog.productsResult)
        ..bundlesGate.complete(const []);
      await tester.pump();
      await tester.pump();

      expect(find.byType(ProductsGridView), findsNothing);
      expect(find.text(S.noProductsYet), findsOneWidget);
    },
  );

  testWidgets('a successful non-empty response shows the products', (
    tester,
  ) async {
    final catalog = _ControlledCatalog(
      categoriesResult: const [_coffee],
      productsResult: const [_latte],
    );
    final cubit = CategoriesCubit(repository: catalog);
    addTearDown(cubit.close);

    await _pumpPage(tester, cubit, catalog);
    await tester.pump();

    catalog
      ..categoriesGate.complete(catalog.categoriesResult)
      ..productsGate.complete(catalog.productsResult)
      ..bundlesGate.complete(const []);
    await tester.pump();
    await tester.pump();

    expect(find.byType(ProductsGridView), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
  });

  testWidgets('a failed load shows the error state, not an empty state', (
    tester,
  ) async {
    final catalog = _ControlledCatalog(failWith: StateError('network down'));
    final cubit = CategoriesCubit(repository: catalog);
    addTearDown(cubit.close);

    await _pumpPage(tester, cubit, catalog);
    await tester.pump();
    await tester.pump();

    expect(find.text(S.couldNotLoadCategories), findsOneWidget);
    expect(find.text(S.noCategories), findsNothing);
    expect(find.text(S.noProductsYet), findsNothing);
  });

  testWidgets('cold entry issues exactly one request per query', (
    tester,
  ) async {
    final catalog = _ControlledCatalog(
      categoriesResult: const [_coffee],
      productsResult: const [_latte],
    );
    final cubit = CategoriesCubit(repository: catalog);
    addTearDown(cubit.close);

    await _pumpPage(tester, cubit, catalog);
    await tester.pump();
    await tester.pump();

    catalog
      ..categoriesGate.complete(catalog.categoriesResult)
      ..productsGate.complete(catalog.productsResult)
      ..bundlesGate.complete(const []);
    await tester.pump();
    await tester.pump();
    // Extra frames must not re-trigger the load.
    await tester.pump();
    await tester.pump();

    expect(catalog.categoryCalls, 1);
    expect(catalog.productCalls, 1);
    expect(catalog.bundleCalls, 1);
  });
}
