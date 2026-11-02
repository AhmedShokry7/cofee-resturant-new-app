import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/bundles/data/model/bundle_model.dart';
import 'package:new_coffee/features/categories/data/model/category_model.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
import 'package:new_coffee/features/categories/presentation/views/categories_page.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_scoped_header.dart';
import 'package:new_coffee/features/categories/presentation/views/widgets/category_tabs.dart';
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
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_card.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';
import 'package:new_coffee/shared/utils/cache_manager.dart';

import 'support/mock_product_repository.dart';
import 'support/pump_harness.dart';

/// What a banner does, from the home row to the products under it.
///
/// The banner page used to draw its strip out of the ten products home happened
/// to load, so a banner pointed at a category (or a product) home had not shown
/// opened onto an empty page. The rows are read for the banner's own target now,
/// plus everything the admin linked to it beyond that one target, and these
/// tests fail if the page stops showing them.
///
/// Pressing a banner takes the customer to what the banner is about - the
/// category, the product, the address - and the banner page is what opens when
/// there is nothing there to open. The page does not draw the picture the
/// customer just pressed on home.
void main() {
  // Home holds its sections in one process-wide cache, so a test that publishes
  // a different banner list would otherwise be handed the previous test's list
  // and tap a banner that is not on the screen it asked for.
  setUp(() => CacheManager().clear());

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

  /// Pumps the two home banner slots with [banners] as the published rows.
  Future<void> pumpHome(
    WidgetTester tester, {
    List<BannerModel> banners = const [categoryBanner, productBanner],
  }) async {
    SharedPreferences.setMockInitialValues({});
    await setSurface(tester);
    final catalog = _LiveShapeCatalog(
      banners: banners,
      categories: const [_coldCategory, _dailyCategory],
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
  }

  /// The picture in the promo slot under the carousel.
  Finder promoPicture() => find.descendant(
    of: find.byType(HomeSingleBannerSection),
    matching: find.byType(BannerImage),
  );

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
    await pumpHome(tester);

    // Every banner slot is wider than the 16:9 pictures the dashboard uploads,
    // and the customer asked for the whole picture rather than a crop.
    expect(
      tester
          .widget<DbImage>(
            find
                .descendant(
                  of: find.byType(BannerImage),
                  matching: find.byType(DbImage),
                )
                .first,
          )
          .fit,
      BoxFit.fill,
    );
  });

  testWidgets('the banner page does not repeat the picture it came from', (
    tester,
  ) async {
    await pumpPage(tester, categoryBanner);

    // The customer pressed that picture to reach this page. Drawing it again
    // above its own text takes the room the products under the banner need, so
    // the picture stays on home.
    expect(find.byType(BannerImage), findsNothing);
  });

  testWidgets('home shows both published banners', (tester) async {
    await pumpHome(tester);

    // The carousel page and the promo slot under it: two published banners must
    // reach the screen, not sit in the database.
    expect(find.byType(BannerImage), findsAtLeastNWidgets(2));
  });

  testWidgets('tapping a category banner opens that category', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byType(BannerImage).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // The categories page loads its own tabs once it is opened.
    await tester.pump();
    await tester.pump();

    // The banner points at the second of the two categories, so a page that
    // simply opened the tabs - or stayed on the first one - would draw the
    // other category's products here.
    expect(find.byType(CategoriesPage), findsOneWidget);
    expect(
      find.byType(CategoryTabs),
      findsNothing,
      reason: 'the banner is about one category, not the whole catalogue',
    );
    expect(find.byType(CategoryScopedHeader), findsOneWidget);
    expect(find.text('الأصناف اليومية'), findsOneWidget);
    expect(find.text('قهوة اليوم'), findsOneWidget);
    expect(find.text('آيس لاتيه'), findsNothing);
    expect(find.byType(BannerDetailsPage), findsNothing);
  });

  testWidgets('tapping a product banner opens the product it points at', (
    tester,
  ) async {
    await pumpHome(tester);

    // The banner row carries the product's id rather than the product, so the
    // tap reads the row before it has anything to show.
    await tester.tap(promoPicture());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('product:iced-latte'), findsOneWidget);
    expect(find.byType(BannerDetailsPage), findsNothing);
  });

  testWidgets('a banner that points at nothing opens the banner page', (
    tester,
  ) async {
    await pumpHome(
      tester,
      banners: const [
        categoryBanner,
        BannerModel(
          id: 'b9',
          titleAr: 'بلا هدف',
          image: '',
          target: BannerTarget.none,
        ),
      ],
    );

    await tester.tap(promoPicture());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // A banner with no target still has its text and its strip, and it is the
    // only page left to open: the tap has to land somewhere.
    expect(find.byType(BannerDetailsPage), findsOneWidget);
  });

  testWidgets('the promo slot shows the second banner, not the first', (
    tester,
  ) async {
    await pumpHome(tester);

    // The slot exists to show a banner the carousel has not already shown, so it
    // must take the second row; the carousel's first slide stays the first row.
    expect(
      tester.widget<BannerImage>(promoPicture()).banner.id,
      productBanner.id,
    );
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
      // A category banner opens the category page, which loads its own tabs.
      BlocProvider(create: (_) => CategoriesCubit(repository: catalog)),
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
          // The product page needs the cart and the branch stack to draw
          // anything, and this file measures where a banner sends the customer
          // rather than what the product page renders. The stand-in answers with
          // the row it was handed, so a banner that opens the wrong product - or
          // one it never read - fails here.
          ProductDetailsPage.routeName: (context) => Scaffold(
            body: Text(
              'product:${(ModalRoute.of(context)!.settings.arguments! as ProductModel).id}',
            ),
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

/// The two categories the banner's own target is looked up among.
///
/// The one a banner points at is deliberately the second: a page that opens on
/// the first tab shows the other category's products, and that is the failure
/// this file watches for.
const _coldCategory = CategoryModel(
  id: 'cat-cold',
  slug: 'cold',
  nameAr: 'آيس',
  nameEn: 'Cold',
  icon: AppIcons.coffeeHot,
);

const _dailyCategory = CategoryModel(
  id: 'cat-daily',
  slug: 'daily',
  // Deliberately not the banner's title or a product's name: this has to be
  // findable as the one thing on the page that names the category.
  nameAr: 'الأصناف اليومية',
  nameEn: 'Daily',
  icon: AppIcons.coffeeHot,
);

/// A catalogue shaped like the database on the day this was written: two
/// published banners, one pointing at a category with a single product and one
/// at a product of its own.
class _LiveShapeCatalog implements CatalogRepository, BannerLinkRepository {
  _LiveShapeCatalog({
    this.banners = const [],
    this.products = const [],
    this.categories = const [],
    this.links = const {},
  });

  final List<BannerModel> banners;
  final List<ProductModel> products;
  final List<CategoryModel> categories;

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
  }) async {
    // No category asked for means the whole branch, which is how the
    // categories page loads: it fetches once and joins each tab itself.
    // Filtering null away here made that page render empty, and a test that
    // looked for a product name passed on the tab pill instead.
    final matching = categoryId == null
        ? products
        : products.where((p) => p.categoryId == categoryId);
    return matching.take(limit).toList();
  }

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
  }) async => categories;

  @override
  Future<List<BundleModel>> getBundles({
    String? branchId,
    int limit = CatalogLimits.bundles,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
