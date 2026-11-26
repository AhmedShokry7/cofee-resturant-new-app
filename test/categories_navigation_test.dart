// Navigation tests for the home category row.
//
// "See all" must open the root of the category tree with nothing selected,
// and a category tap must open that category's products even when the shared
// catalogue tab was left on a different category by an earlier visit.
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/cart/data/repositories/local_cart_repository.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/categories/presentation/views/categories_page.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/all_categories_view.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_scoped_header.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_tabs.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/category_circle_item.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_categories_section.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/products_grid_view.dart';

import 'support/mock_product_repository.dart';

const _coffee = CategoryModel(
  id: 'cat-coffee',
  slug: 'coffee',
  nameEn: 'Coffee',
  nameAr: 'قهوة',
  icon: AppIcons.coffeeHot,
);

const _cold = CategoryModel(
  id: 'cat-cold',
  slug: 'cold-coffee',
  nameEn: 'Cold Coffee',
  nameAr: 'آيس',
  icon: AppIcons.coffeeIced,
);

const _dessert = CategoryModel(
  id: 'cat-dessert',
  slug: 'desserts',
  nameEn: 'Desserts',
  nameAr: 'حلويات',
  icon: AppIcons.dessert,
);

/// A sub-category, to prove the root page stays at level one.
const _child = CategoryModel(
  id: 'cat-child',
  slug: 'coffee-beans',
  nameEn: 'Coffee Beans',
  nameAr: 'حبوب القهوة',
  parentId: 'cat-coffee',
  icon: AppIcons.coffeeHot,
);

const _latte = ProductModel(
  id: 'prod-latte',
  name: 'Latte',
  price: 14,
  image: '',
  categoryId: 'cat-coffee',
);

const _frappe = ProductModel(
  id: 'prod-frappe',
  name: 'Frappe',
  price: 22,
  image: '',
  categoryId: 'cat-cold',
);

const _beans = ProductModel(
  id: 'prod-beans',
  name: 'Beans',
  price: 40,
  image: '',
  categoryId: 'cat-child',
);

const _allCategories = [_coffee, _cold, _dessert, _child];
const _allProducts = [_latte, _frappe, _beans];

class _Catalog extends MockProductRepository {
  const _Catalog({
    this.categories = _allCategories,
    this.products = _allProducts,
  });

  final List<CategoryModel> categories;
  final List<ProductModel> products;

  @override
  Future<List<CategoryModel>> getCategories({
    bool includeInactive = false,
  }) async => categories;

  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = 100,
    int offset = 0,
  }) async {
    final items = categoryId == null
        ? products
        : products
              .where((product) => product.categoryId == categoryId)
              .toList();
    if (offset >= items.length) return const [];
    return items.sublist(offset, (offset + limit).clamp(0, items.length));
  }

  @override
  Future<List<BundleModel>> getBundles({
    String? branchId,
    int limit = 20,
  }) async => const [];

  @override
  Future<CategoryModel?> getCategoryById(String id) async {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }
}

/// Home with a known category row and no network behind it.
class _SeededHomeCubit extends HomeCubit {
  _SeededHomeCubit(List<CategoryModel> categories)
    : super(repository: const MockProductRepository()) {
    emit(
      HomeState(categories: categories, isLoading: false, hasLoadedOnce: true),
    );
  }

  @override
  Future<void> load({bool forceRefresh = false}) async {}
}

const _phoneWidth = 360.0;

Future<void> _pumpHome(
  WidgetTester tester, {
  required CategoriesCubit categories,
  required HomeCubit home,
  required _Catalog catalog,
}) async {
  tester.view.physicalSize = const Size(_phoneWidth, 800) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
    MultiBlocProvider(
      providers: [
        BlocProvider<CategoriesCubit>.value(value: categories),
        BlocProvider<HomeCubit>.value(value: home),
        BlocProvider<CartCubit>.value(value: cart),
        BlocProvider<FavoritesCubit>.value(value: favorites),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: HomeCategoriesSection()),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The grid the page actually drew, by product id.
List<String> _gridIds(WidgetTester tester) => tester
    .widget<ProductsGridView>(find.byType(ProductsGridView))
    .products
    .map((product) => product.id)
    .toList();

Future<void> _tapBack(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(CategoryScopedHeader),
      matching: find.byType(InkWell),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _openFromHome(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<CategoriesCubit> _loadedCubit(
  WidgetTester tester,
  _Catalog catalog,
) async {
  final cubit = CategoriesCubit(repository: catalog);
  addTearDown(cubit.close);
  cubit.ensureLoaded();
  await cubit.stream.firstWhere((state) => !state.isLoading);
  return cubit;
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

  testWidgets('See all opens the root categories, never a product page', (
    tester,
  ) async {
    const catalog = _Catalog();
    final categories = await _loadedCubit(tester, catalog);
    // What a previous visit left on the catalogue tab: a category is selected.
    categories.select(1);
    final home = _SeededHomeCubit(const [_cold, _coffee, _dessert, _child]);
    addTearDown(home.close);

    await _pumpHome(
      tester,
      categories: categories,
      home: home,
      catalog: catalog,
    );
    await tester.tap(find.text(S.seeAll));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CategoriesPage), findsOneWidget);
    expect(find.byType(AllCategoriesView), findsOneWidget);
    expect(find.text(S.allCategories), findsOneWidget);
    expect(
      find.byType(CategoryTabs),
      findsNothing,
      reason: 'the all-categories page is not the catalogue browser',
    );
    expect(
      find.byType(ProductsGridView),
      findsNothing,
      reason: 'a selected tab from an earlier visit must not become a grid',
    );
    final roots = find.descendant(
      of: find.byType(AllCategoriesView),
      matching: find.byType(CategoryCircleItem),
    );
    expect(roots, findsNWidgets(3));
    expect(
      find.descendant(
        of: find.byType(AllCategoriesView),
        matching: find.text('Coffee'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AllCategoriesView),
        matching: find.text('Cold Coffee'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AllCategoriesView),
        matching: find.text('Desserts'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AllCategoriesView),
        matching: find.text('Coffee Beans'),
      ),
      findsNothing,
      reason: 'only categories with no parent belong on the root page',
    );
    expect(
      categories.state.index,
      1,
      reason: 'opening the page neither reads nor writes the shared selection',
    );

    await _tapBack(tester);
    expect(find.byType(CategoriesPage), findsNothing);
    expect(find.byType(HomeCategoriesSection), findsOneWidget);
  });

  testWidgets('a category tapped on home opens its own products', (
    tester,
  ) async {
    const catalog = _Catalog();
    final categories = await _loadedCubit(tester, catalog);
    final home = _SeededHomeCubit(const [_cold, _coffee, _dessert, _child]);
    addTearDown(home.close);

    await _pumpHome(
      tester,
      categories: categories,
      home: home,
      catalog: catalog,
    );
    await _openFromHome(tester, 'Coffee');

    expect(find.byType(CategoriesPage), findsOneWidget);
    expect(find.byType(CategoryTabs), findsNothing);
    expect(find.byType(CategoryScopedHeader), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CategoryScopedHeader),
        matching: find.text('Coffee'),
      ),
      findsOneWidget,
      reason: 'the header names it',
    );
    expect(_gridIds(tester), ['prod-latte']);
    expect(
      find.descendant(
        of: find.byType(ProductsGridView),
        matching: find.text('Beans'),
      ),
      findsNothing,
      reason: 'a child category has its own products, as the catalogue does',
    );

    await _tapBack(tester);
    expect(find.byType(CategoriesPage), findsNothing);
    expect(find.byType(HomeCategoriesSection), findsOneWidget);
  });

  testWidgets('a second category opens its own products, not the first one', (
    tester,
  ) async {
    const catalog = _Catalog();
    final categories = await _loadedCubit(tester, catalog);
    // The tab was left on Cold Coffee before the customer came home.
    categories.select(1);
    final home = _SeededHomeCubit(const [_cold, _coffee]);
    addTearDown(home.close);

    await _pumpHome(
      tester,
      categories: categories,
      home: home,
      catalog: catalog,
    );
    await _openFromHome(tester, 'Coffee');
    expect(_gridIds(tester), ['prod-latte']);
    expect(
      categories.state.index,
      1,
      reason: 'the category page must not move the catalogue tab',
    );

    await _tapBack(tester);
    await _openFromHome(tester, 'Cold Coffee');

    expect(
      find.descendant(
        of: find.byType(CategoryScopedHeader),
        matching: find.text('Cold Coffee'),
      ),
      findsOneWidget,
    );
    expect(_gridIds(tester), [
      'prod-frappe',
    ], reason: 'the page carries its own id, not the previous category');
    expect(categories.state.index, 1);
  });

  testWidgets('a category with no products shows the catalogue empty state', (
    tester,
  ) async {
    const catalog = _Catalog();
    final categories = await _loadedCubit(tester, catalog);
    final home = _SeededHomeCubit(const [_dessert]);
    addTearDown(home.close);

    await _pumpHome(
      tester,
      categories: categories,
      home: home,
      catalog: catalog,
    );
    await _openFromHome(tester, 'Desserts');

    expect(find.text(S.noProductsYet), findsOneWidget);
    expect(find.text(S.productsIn('Desserts')), findsOneWidget);
    expect(find.byType(ProductsGridView), findsNothing);
  });

  testWidgets('an empty catalogue shows the empty state on the root page', (
    tester,
  ) async {
    const catalog = _Catalog(categories: [], products: []);
    final categories = await _loadedCubit(tester, catalog);

    await tester.pumpWidget(
      BlocProvider<CategoriesCubit>.value(
        value: categories,
        child: const MaterialApp(home: CategoriesPage.all()),
      ),
    );
    await tester.pump();

    expect(find.text(S.noCategories), findsOneWidget);
    expect(find.byType(CategoryCircleItem), findsNothing);
    expect(find.byType(ProductsGridView), findsNothing);
  });
}
