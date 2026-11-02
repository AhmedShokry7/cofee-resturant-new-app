import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/favorites/data/repositories/favorite_repository.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/home/data/model/banner_links.dart';
import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/home/data/repositories/banner_link_repository.dart';
import 'package:new_coffee/features/home/presentation/manager/home/home_cubit.dart';
import 'package:new_coffee/features/home/presentation/views/banner_details_page.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/banner_image.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_banner_section.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_products_carousel.dart';
import 'package:new_coffee/features/home/presentation/views/widgets/home_single_banner_section.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_card.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

import 'support/mock_product_repository.dart';
import 'support/pump_harness.dart';

/// What a banner does, from the home row to the products under it.
///
/// The banner page used to draw its strip out of the ten products home happened
/// to load, so a banner pointed at a category (or a product) home had not shown
/// opened onto an empty page. The rows are read for the banner's own target now,
/// plus everything the admin linked to it beyond that one target, and these
/// tests fail if the page stops showing them.
void main() {
  const categoryBanner = BannerModel(
    id: '48e9874e',
    titleAr: 'قهوة اليوم',
    image: '',
    target: BannerTarget.category,
    targetId: 'cat-daily',
  );
  const productBanner = BannerModel(
    id: '8dd55478',
    titleAr: 'آيس لاتيه',
    image: '',
    target: BannerTarget.product,
    targetId: 'iced-latte',
  );

  Future<void> setSurface(WidgetTester tester) async {
    tester.view.physicalSize = phoneViewport * phoneDevicePixelRatio;
    tester.view.devicePixelRatio = phoneDevicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Pumps one banner page with the catalogue and the branch behind it.
  ///
  /// [links] is what the admin put in the banner's link tables, keyed by the
  /// `target_id` the links hang off.
  Future<void> pumpPage(
    WidgetTester tester,
    BannerModel banner, {
    Map<String, BannerLinks> links = const {},
    List<ProductModel> products = const [],
  }) async {
    final catalog = _LiveShapeCatalog(
      banners: const [categoryBanner, productBanner],
      products: products.isEmpty
          ? [
              _product('coffee-of-the-day', 'cat-daily', 'قهوة اليوم'),
              _product('iced-latte', 'cat-cold', 'آيس لاتيه'),
            ]
          : products,
      links: links,
    );
    final home = HomeCubit(repository: catalog)..branchId = 'branch-1';
    final favorites = FavoritesCubit(
      repository: MockProductRepository(),
      favorites: FavoritesRepositoryImpl(),
    );
    addTearDown(home.close);
    addTearDown(favorites.close);

    await tester.pumpWidget(
      _harness(
        catalog: catalog,
        home: home,
        favorites: favorites,
        child: BannerDetailsPage(banner: banner),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('a category banner shows its own category products', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await setSurface(tester);
    await pumpPage(tester, categoryBanner);

    expect(find.byType(ProductCard), findsOneWidget);
  });

  /// The ids the page hands to the strip under the banner.
  ///
  /// The strip is a horizontal list, so it only builds the cards that fit the
  /// screen: counting `ProductCard` widgets would measure the viewport, not what
  /// the banner resolved.
  List<String> stripIds(WidgetTester tester) => tester
      .widget<HomeProductsCarousel>(find.byType(HomeProductsCarousel))
      .products
      .map((product) => product.id)
      .toList();

  testWidgets('a banner shows every product and category linked to it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await setSurface(tester);
    // The shape the single `target_id` could not carry: a banner pointing at one
    // category whose admin also chose a product from elsewhere and a second
    // category. Before the link tables, only the tapped target reached the page.
    await pumpPage(
      tester,
      categoryBanner,
      products: [
        _product('coffee-of-the-day', 'cat-daily', 'قهوة اليوم'),
        _product('iced-latte', 'cat-cold', 'آيس لاتيه'),
        _product('mocha', 'cat-hot', 'موكا'),
      ],
      links: const {
        'cat-daily': BannerLinks(
          productIds: ['mocha'],
          categoryIds: ['cat-cold'],
        ),
      },
    );

    expect(
      stripIds(tester),
      ['coffee-of-the-day', 'mocha', 'iced-latte'],
      reason: 'the banner\'s own rows first, then the chosen product, then the chosen category',
    );
    expect(find.byType(ProductCard), findsWidgets);
  });

  testWidgets('a product linked through its own category is not shown twice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await setSurface(tester);
    await pumpPage(
      tester,
      categoryBanner,
      products: [
        _product('coffee-of-the-day', 'cat-daily', 'قهوة اليوم'),
        _product('iced-latte', 'cat-cold', 'آيس لاتيه'),
      ],
      links: const {
        'cat-daily': BannerLinks(
          productIds: ['iced-latte'],
          categoryIds: ['cat-cold'],
        ),
      },
    );

    expect(stripIds(tester), ['coffee-of-the-day', 'iced-latte']);
    expect(find.byType(ProductCard), findsNWidgets(2));
  });

  testWidgets('a product banner shows the product it points at', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await setSurface(tester);
    await pumpPage(tester, productBanner);

    expect(find.byType(ProductCard), findsOneWidget);
    expect(find.text('آيس لاتيه'), findsWidgets);
  });

  testWidgets(
    'a banner with only a picture and a target offers no empty button',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await setSurface(tester);
      // Both live rows are shaped like this: an image, a target, and nothing but
      // a placeholder in the text columns.
      await pumpPage(
        tester,
        const BannerModel(
          id: 'b4',
          titleAr: '1',
          image: '',
          target: BannerTarget.category,
          targetId: 'cat-daily',
        ),
      );

      expect(find.byType(CustomBtn), findsNothing);
      expect(find.byType(ProductCard), findsOneWidget);
    },
  );

  testWidgets('the banner picture shows the whole image', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await setSurface(tester);
    await pumpPage(tester, categoryBanner);

    // Every banner slot is wider than the 16:9 pictures the dashboard uploads,
    // and the customer asked for the whole picture rather than a crop.
    expect(tester.widget<DbImage>(find.byType(DbImage).first).fit, BoxFit.fill);
  });

  testWidgets('home shows both banners and a tap opens the page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await setSurface(tester);
    final catalog = _LiveShapeCatalog(
      banners: const [categoryBanner, productBanner],
      products: [
        _product('coffee-of-the-day', 'cat-daily', 'قهوة اليوم'),
        _product('iced-latte', 'cat-cold', 'آيس لاتيه'),
      ],
    );
    final home = HomeCubit(repository: catalog)..branchId = 'branch-1';
    final favorites = FavoritesCubit(
      repository: MockProductRepository(),
      favorites: FavoritesRepositoryImpl(),
    );
    addTearDown(home.close);
    addTearDown(favorites.close);

    await tester.pumpWidget(
      _harness(
        catalog: catalog,
        home: home,
        favorites: favorites,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: const [HomeBannerSection(), HomeSingleBannerSection()],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The carousel page and the promo slot under it: two published banners must
    // reach the screen, not sit in the database.
    expect(find.byType(BannerImage), findsAtLeastNWidgets(2));

    await tester.tap(find.byType(BannerImage).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(BannerDetailsPage), findsOneWidget);
    expect(find.byType(ProductCard), findsOneWidget);
  });

  testWidgets('the promo slot shows the second banner, not the first', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await setSurface(tester);
    final catalog = _LiveShapeCatalog(
      banners: const [categoryBanner, productBanner],
      products: [
        _product('coffee-of-the-day', 'cat-daily', 'قهوة اليوم'),
        _product('iced-latte', 'cat-cold', 'آيس لاتيه'),
      ],
    );
    final home = HomeCubit(repository: catalog)..branchId = 'branch-1';
    final favorites = FavoritesCubit(
      repository: MockProductRepository(),
      favorites: FavoritesRepositoryImpl(),
    );
    addTearDown(home.close);
    addTearDown(favorites.close);

    await tester.pumpWidget(
      _harness(
        catalog: catalog,
        home: home,
        favorites: favorites,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: const [HomeBannerSection(), HomeSingleBannerSection()],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The slot exists to show a banner the carousel has not already shown, so it
    // must take the second row; the carousel's first slide stays the first row.
    final promo = tester.widget<BannerImage>(
      find.descendant(
        of: find.byType(HomeSingleBannerSection),
        matching: find.byType(BannerImage),
      ),
    );
    expect(promo.banner.id, productBanner.id);
  });
}

Widget _harness({
  required CatalogRepository catalog,
  required HomeCubit home,
  required FavoritesCubit favorites,
  required Widget child,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider.value(value: home),
      BlocProvider.value(value: favorites),
    ],
    child: RepositoryProvider<CatalogRepository>.value(
      value: catalog,
      child: MaterialApp(
        home: child,
        // The home row opens a banner with pushNamed, the same way the app does.
        routes: {
          BannerDetailsPage.routeName: (context) => BannerDetailsPage(
            banner: ModalRoute.of(context)!.settings.arguments! as BannerModel,
          ),
        },
      ),
    ),
  );
}

/// A product row that carries its own name rather than a generated one.
ProductModel _product(String id, String categoryId, String name) =>
    ProductModel(
      id: id,
      name: name,
      nameAr: name,
      price: 15,
      image: '',
      categoryId: categoryId,
    );

/// A catalogue shaped like the database on the day this was written: two
/// published banners, one pointing at a category with a single product and one
/// at a product of its own.
class _LiveShapeCatalog implements CatalogRepository, BannerLinkRepository {
  _LiveShapeCatalog({
    this.banners = const [],
    this.products = const [],
    this.links = const {},
  });

  final List<BannerModel> banners;
  final List<ProductModel> products;

  /// The link tables, keyed by the id the links hang off.
  final Map<String, BannerLinks> links;

  @override
  Future<BannerLinks> getBannerLinks(String bannerId) async =>
      links[bannerId] ?? BannerLinks.none;

  @override
  Future<List<BannerModel>> getBanners({
    int limit = CatalogLimits.banners,
  }) async => banners;

  @override
  Future<ProductModel?> getById(String id, {String? branchId}) async {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  Future<List<ProductModel>> getProducts({
    String? branchId,
    String? categoryId,
    int limit = CatalogLimits.products,
    int offset = 0,
  }) async =>
      products.where((p) => p.categoryId == categoryId).take(limit).toList();

  // Home loads beside these pages, so the other sections answer empty rather
  // than falling through noSuchMethod.
  @override
  Future<List<FeaturedProduct>> getFeatured({
    String? branchId,
    int limit = CatalogLimits.featured,
  }) async => const [];

  @override
  Future<List<CategoryModel>> getCategories({
    bool includeInactive = false,
  }) async => const [];

  @override
  Future<List<BundleModel>> getBundles({
    String? branchId,
    int limit = CatalogLimits.bundles,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
