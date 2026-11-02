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
import 'package:new_coffee/features/categories/presentation/views/widgets/category_scoped_header.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_tabs.dart';
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

/// The second tab, so a page that opens on the wrong one is measurable.
const _cold = CategoryModel(
  id: 'cat-cold',
  slug: 'cold-coffee',
  nameEn: 'Cold Coffee',
  nameAr: 'آيس',
  icon: AppIcons.coffeeHot,
);

const _frappe = ProductModel(
  id: 'prod-frappe',
  name: 'Frappe',
  price: 22,
  image: '',
  categoryId: 'cat-cold',
);

/// The ids the grid actually drew.
List<String> gridIds(WidgetTester tester) => tester
    .widget<ProductsGridView>(find.byType(ProductsGridView))
    .products
    .map((product) => product.id)
    .toList();

/// The window this file renders the page into.
const _phoneWidth = 360.0;

Future<void> _pumpPage(
  WidgetTester tester,
  CategoriesCubit cubit,
  _ControlledCatalog catalog, {
  String? initialCategoryId,
  bool pushed = false,
}) async {
  tester.view.physicalSize = const Size(_phoneWidth, 800) * 3.0;
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
      home: pushed
          ? _PushedPage(
              page: CategoriesPage(initialCategoryId: initialCategoryId),
              categories: cubit,
              cart: cart,
              favorites: favorites,
            )
          : MultiBlocProvider(
              providers: [
                BlocProvider<CategoriesCubit>.value(value: cubit),
                BlocProvider<CartCubit>.value(value: cart),
                BlocProvider<FavoritesCubit>.value(value: favorites),
              ],
              child: CategoriesPage(initialCategoryId: initialCategoryId),
            ),
    ),
  );
}

/// The page one route deep, the way a banner opens it.
///
/// At the root there is nothing to go back to, so a pop does nothing and the
/// arrow on a one-category page could not be tested from there. The providers
/// travel with the route: in the app they sit above the navigator, but a route
/// pushed from under them cannot see them, so the harness repeats what the app
/// gives the route.
class _PushedPage extends StatelessWidget {
  const _PushedPage({
    required this.page,
    required this.categories,
    required this.cart,
    required this.favorites,
  });

  final Widget page;
  final CategoriesCubit categories;
  final CartCubit cart;
  final FavoritesCubit favorites;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MultiBlocProvider(
                providers: [
                  BlocProvider<CategoriesCubit>.value(value: categories),
                  BlocProvider<CartCubit>.value(value: cart),
                  BlocProvider<FavoritesCubit>.value(value: favorites),
                ],
                child: page,
              ),
            ),
          ),
          child: const Text('push'),
        ),
      ),
    );
  }
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

  // What a banner tap opens: the categories page asked for one category.
  //
  // The app holds a single CategoriesCubit above the tab bar, so a customer who
  // has visited the Categories tab once arrives with the list already loaded and
  // on whichever tab they left. The page used to *select* the asked-for category
  // and wait for the load to finish before doing it; a stream only reports
  // changes, so on an already loaded cubit it waited for something that had
  // already happened, never selected, and showed the previous tab's products.
  // It now reads the category by id, which cannot be stale, and shows no row of
  // the categories nobody asked for.
  testWidgets('a page opened for one category draws that category', (
    tester,
  ) async {
    final catalog = _ControlledCatalog(
      categoriesResult: const [_coffee, _cold],
      productsResult: const [_latte, _frappe],
    );
    final cubit = CategoriesCubit(repository: catalog);
    addTearDown(cubit.close);

    catalog
      ..categoriesGate.complete(catalog.categoriesResult)
      ..productsGate.complete(catalog.productsResult)
      ..bundlesGate.complete(const []);
    // The page's own entry point, the way a previous visit left it: the
    // app-wide cubit has started and finished its one load.
    cubit.ensureLoaded();
    await cubit.stream.firstWhere((state) => !state.isLoading);
    expect(cubit.state.index, 0, reason: 'the tab the customer left open');

    await _pumpPage(tester, cubit, catalog, initialCategoryId: 'cat-cold');
    await tester.pump();
    await tester.pump();

    expect(gridIds(tester), [
      'prod-frappe',
    ], reason: 'the page was asked for the cold category, not the first tab');
    expect(
      find.byType(CategoryTabs),
      findsNothing,
      reason: 'the other categories are not what this banner is about',
    );
    expect(find.text(_cold.label), findsOneWidget);
  });

  testWidgets('a page opened for one category while tabs load lands on it', (
    tester,
  ) async {
    final catalog = _ControlledCatalog(
      categoriesResult: const [_coffee, _cold],
      productsResult: const [_latte, _frappe],
    );
    final cubit = CategoriesCubit(repository: catalog);
    addTearDown(cubit.close);

    await _pumpPage(tester, cubit, catalog, initialCategoryId: 'cat-cold');
    await tester.pump();

    catalog
      ..categoriesGate.complete(catalog.categoriesResult)
      ..productsGate.complete(catalog.productsResult)
      ..bundlesGate.complete(const []);
    await tester.pump();
    await tester.pump();

    expect(gridIds(tester), ['prod-frappe']);
  });

  testWidgets('a page opened for one category leaves the catalogue tab alone', (
    tester,
  ) async {
    // The page a banner opens shares its cubit with the Categories tab. Picking
    // a tab there would silently move the tab the customer was reading, so the
    // one-category page reads by id and selects nothing.
    final catalog = _ControlledCatalog(
      categoriesResult: const [_coffee, _cold],
      productsResult: const [_latte, _frappe],
    );
    final cubit = CategoriesCubit(repository: catalog);
    addTearDown(cubit.close);

    catalog
      ..categoriesGate.complete(catalog.categoriesResult)
      ..productsGate.complete(catalog.productsResult)
      ..bundlesGate.complete(const []);
    cubit.ensureLoaded();
    await cubit.stream.firstWhere((state) => !state.isLoading);
    cubit.select(1);
    expect(cubit.state.index, 1, reason: 'the tab the customer left open');

    await _pumpPage(tester, cubit, catalog, initialCategoryId: 'cat-coffee');
    await tester.pump();
    await tester.pump();

    expect(cubit.state.index, 1, reason: 'the banner did not move the tab bar');
    expect(gridIds(tester), [
      'prod-latte',
    ], reason: 'and it still shows the category the banner named');
  });

  testWidgets(
    'a page opened for a category the catalogue no longer has says so',
    (tester) async {
      // The banner was written while the category existed; the row was deleted or
      // unpublished since. "No categories yet" would blame the whole catalogue.
      final catalog = _ControlledCatalog(
        categoriesResult: const [_coffee, _cold],
        productsResult: const [_latte, _frappe],
      );
      final cubit = CategoriesCubit(repository: catalog);
      addTearDown(cubit.close);

      catalog
        ..categoriesGate.complete(catalog.categoriesResult)
        ..productsGate.complete(catalog.productsResult)
        ..bundlesGate.complete(const []);
      cubit.ensureLoaded();
      await cubit.stream.firstWhere((state) => !state.isLoading);

      await _pumpPage(tester, cubit, catalog, initialCategoryId: 'cat-gone');
      await tester.pump();
      await tester.pump();

      expect(find.text(S.categoryUnavailable), findsOneWidget);
      expect(find.text(S.noCategories), findsNothing);
      expect(find.text(S.noProductsYet), findsNothing);
    },
  );

  testWidgets('the one-category page gives the customer a way back', (
    tester,
  ) async {
    // With the row of tabs gone, the screen has no other exit on it: the arrow
    // has to be there and has to leave.
    final catalog = _ControlledCatalog(
      categoriesResult: const [_coffee, _cold],
      productsResult: const [_latte, _frappe],
    );
    final cubit = CategoriesCubit(repository: catalog);
    addTearDown(cubit.close);

    catalog
      ..categoriesGate.complete(catalog.categoriesResult)
      ..productsGate.complete(catalog.productsResult)
      ..bundlesGate.complete(const []);
    cubit.ensureLoaded();
    await cubit.stream.firstWhere((state) => !state.isLoading);

    await _pumpPage(
      tester,
      cubit,
      catalog,
      initialCategoryId: 'cat-cold',
      pushed: true,
    );

    await tester.tap(find.text('push'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CategoriesPage), findsOneWidget);
    expect(find.byType(CategoryTabs), findsNothing);
    expect(find.byType(CategoryScopedHeader), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(CategoryScopedHeader),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CategoriesPage), findsNothing);
  });
}
