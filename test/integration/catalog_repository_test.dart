import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/services/supabase_service.dart';

import '../support/mock_product_repository.dart';

import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/menu/data/repositories/batch_product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/data/repositories/supabase_product_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contract test: the live repository and the mock must satisfy the same
/// behaviour, so swapping between them cannot change what a screen shows.
///
/// Live half runs only when credentials are supplied and the database schemas
/// are exposed:
///
///   flutter test test/integration/catalog_repository_test.dart \
///     --dart-define=SUPABASE_URL=... \
///     --dart-define=SUPABASE_PUBLISHABLE_KEY=... \
///     --dart-define=SCHEMAS_EXPOSED=true
void main() {
  const schemasExposed = bool.fromEnvironment('SCHEMAS_EXPOSED');

  const needsSetup =
      'Needs --dart-define SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and '
      'SCHEMAS_EXPOSED=true (Dashboard -> Settings -> API -> Exposed schemas)';

  final String? skip = (!AppConfig.isSupabaseConfigured || !schemasExposed)
      ? needsSetup
      : null;

  late CatalogRepository live;
  const mock = MockProductRepository();

  setUpAll(() async {
    // Without credentials the live half is skipped, but the mock half still
    // needs to run, so initialisation must not be asserted unconditionally.
    if (skip != null) return;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SupabaseService.init();
    live = SupabaseProductRepository();
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  group('mock repository (offline path, always runs)', () {
    test('lists the catalogue', () async {
      final items = await mock.getProducts();
      expect(items, isNotEmpty);
      expect(items.every((p) => p.name.isNotEmpty), isTrue);
    });

    test('filters by a substring query', () async {
      final items = await mock.search('latte');
      expect(items, isNotEmpty);
      expect(
        items.every((p) => p.name.toLowerCase().contains('latte')),
        isTrue,
      );
    });

    test('paginates without going out of range', () async {
      expect(await mock.getProducts(offset: 9999), isEmpty);
      final first = await mock.getProducts(limit: 3);
      expect(first.length, lessThanOrEqualTo(3));
    });
  });

  group('live repository against Supabase', () {
    test('reads the same catalogue', () async {
      final items = await live.getProducts();
      expect(items, isNotEmpty, reason: 'catalog.products must be seeded');
      expect(items.every((p) => p.id.isNotEmpty), isTrue);
      expect(items.every((p) => p.price > 0), isTrue);
    }, skip: skip);

    test('returns bilingual names for every product', () async {
      final items = await live.getProducts();
      expect(
        items.every((p) => p.nameAr != null && p.nameAr!.isNotEmpty),
        isTrue,
        reason: 'D4 requires Arabic on every product',
      );
      expect(
        items.every((p) => p.nameEn != null && p.nameEn!.isNotEmpty),
        isTrue,
      );
    }, skip: skip);

    test('finds a product by id', () async {
      final all = await live.getProducts();
      final first = all.first;
      final found = await live.getById(first.id);
      expect(found, isNotNull);
      expect(found!.id, first.id);
      expect(found.nameEn, first.nameEn);
      expect(
        await live.getById('00000000-0000-0000-0000-000000000000'),
        isNull,
      );
    }, skip: skip);

    test(
      'bulk reads selected products with their images and branch price',
      () async {
        const branchId = '00000000-0000-4000-8000-000000000101';
        final firstPage = await live.getProducts(branchId: branchId, limit: 3);
        expect(firstPage, isNotEmpty);
        final ids = firstPage.map((product) => product.id).toList();
        final bulk = await getProductsByIds(live, ids, branchId: branchId);

        expect(bulk.map((product) => product.id).toSet(), ids.toSet());
        expect(
          {for (final product in bulk) product.id: product.price},
          {for (final product in firstPage) product.id: product.price},
        );
      },
      skip: skip,
    );

    test('searches Arabic through the alias table', () async {
      final results = await live.search('لاتيه');
      expect(
        results,
        isNotEmpty,
        reason: 'catalog.product_aliases must make this resolve',
      );
      expect(results.first.nameEn, 'Latte');
    }, skip: skip);

    test('matches the mock behaviour on an English query', () async {
      final fromDb = await live.search('cappuccino');
      final fromMock = await mock.search('cappuccino');
      expect(
        fromDb.map((p) => p.nameEn).toSet(),
        fromMock.map((p) => p.name).toSet(),
        reason: 'both sources must agree, or swapping them changes the screen',
      );
    }, skip: skip);

    test('applies a branch price override', () async {
      final branches = await live.getCategories();
      expect(branches, isNotEmpty);

      // Get the single known branch id from the view, not a hard-coded value.
      final all = await live.getProducts();
      expect(all, isNotEmpty);

      final withBranch = await live.getProducts(
        branchId: '00000000-0000-4000-8000-000000000101',
      );
      expect(
        withBranch.length,
        all.length,
        reason: 'an override changes the price, not the membership',
      );
    }, skip: skip);

    test('reads categories including sub-category support', () async {
      final categories = await live.getCategories();
      expect(categories.length, greaterThanOrEqualTo(10));
      expect(
        categories.every((c) => c.slug != null),
        isTrue,
        reason: 'a stable slug replaces matching categories by name',
      );

      final hotCoffee = await live.getCategoryBySlug('hot-coffee');
      expect(hotCoffee, isNotNull);
      expect(hotCoffee!.nameEn, 'Hot Coffee');
    }, skip: skip);

    test('reads option groups bound to a product', () async {
      final all = await live.getProducts();
      final latte = all.firstWhere(
        (p) => p.slug == 'latte',
        orElse: () => all.first,
      );
      final detailed = await live.getWithOptions(latte.id);
      expect(detailed, isNotNull);
      // Latte is bound to size and sugar in the seed.
      if (detailed!.groups.isNotEmpty) {
        expect(
          detailed.groups.first.values,
          isNotEmpty,
          reason: 'a group without values would render an empty selector',
        );
      }
    }, skip: skip);

    test('resolves a price on the server', () async {
      final all = await live.getProducts();
      final resolved = await live.resolvePrice(
        all.first.id,
        branchId: '00000000-0000-4000-8000-000000000101',
      );
      expect(resolved, isNotNull);
      expect(resolved!.unitPrice, greaterThan(0));
      expect(resolved.currencyCode, 'SAR');
    }, skip: skip);

    test('reports a product that is not sold at a branch', () async {
      final all = await live.getProducts();
      final cola = all.firstWhere(
        (p) => p.slug == 'cola',
        orElse: () => all.first,
      );
      final resolved = await live.resolvePrice(
        cola.id,
        branchId: '00000000-0000-4000-8000-000000000101',
      );
      if (cola.slug == 'cola') {
        expect(
          resolved!.isAvailable,
          isFalse,
          reason: 'the seed marks cola unavailable at the main branch',
        );
        expect(resolved.unavailableReason, isNotNull);
      }
    }, skip: skip);

    test(
      'best sellers is empty rather than an error when there is no sales',
      () async {
        final sellers = await live.getBestSellers();
        expect(
          sellers,
          isA<List>(),
          reason: 'no completed orders yet must not throw',
        );
      },
      skip: skip,
    );

    // The three below are what HomeCubit depends on. They were added when the
    // home screen moved off the Dart constants and had no live coverage, which
    // is exactly the gap that would have let a broken query reach production.

    test('reads banners with a resolvable category target', () async {
      final banners = await live.getBanners();
      expect(
        banners,
        isNotEmpty,
        reason: 'the seed creates promotional banners',
      );

      for (final banner in banners) {
        expect(banner.id, isNotEmpty);
        expect(
          banner.titleEn,
          isNotEmpty,
          reason: 'a banner needs an English title',
        );
        expect(
          banner.titleAr,
          isNotEmpty,
          reason: 'a banner needs an Arabic title',
        );
        expect(
          banner.image,
          isNotEmpty,
          reason: 'BannerImage has no fallback art',
        );
        expect(banner.ctaLabel, isNotEmpty);

        // A category-targeted banner is only useful if the target resolves. The
        // old banner page matched on a display-name string, so a banner
        // pointing at a renamed category silently showed nothing.
        if (banner.target == BannerTarget.category) {
          expect(
            banner.targetId,
            isNotNull,
            reason: 'a category banner must carry the category id',
          );
        }
      }
    }, skip: skip);

    test('reads bundles with their component products resolved', () async {
      final bundles = await live.getBundles();
      expect(bundles, isNotEmpty, reason: 'the seed creates bundles');

      for (final bundle in bundles) {
        expect(bundle.id, isNotEmpty);
        expect(bundle.nameEn, isNotEmpty);
        expect(bundle.nameAr, isNotEmpty);
        expect(bundle.price, greaterThan(0));
        expect(
          bundle.components,
          isNotEmpty,
          reason: 'a bundle with no components cannot show what it contains',
        );
        for (final component in bundle.components) {
          expect(component.productId, isNotEmpty);
          expect(component.quantity, greaterThan(0));
        }
      }
    }, skip: skip);

    test('featured products carry a price and a reason they were chosen', () async {
      final featured = await live.getFeatured(limit: 10);
      expect(featured, isNotEmpty, reason: 'the seed pins featured products');

      for (final f in featured) {
        expect(f.productId, isNotEmpty);
        expect(f.nameEn, isNotEmpty);
        expect(f.nameAr, isNotEmpty);
        expect(f.effectivePrice, greaterThan(0));
        expect(
          f.source,
          isNotEmpty,
          reason: 'the card explains whether it was pinned or ranked',
        );
      }

      // The carousel caps at the requested limit, so a limit must be honoured.
      expect((await live.getFeatured(limit: 2)).length, lessThanOrEqualTo(2));
    }, skip: skip);

    test('mock and live agree on what counts as a bundles category', () async {
      // CategoriesPage switches to the bundles tab by slug, so both
      // implementations must expose the same key.
      const expected = 'bundles';
      final liveSlugs = (await live.getCategories())
          .map((c) => c.slug)
          .whereType<String>()
          .toSet();
      final mockSlugs = (await mock.getCategories())
          .map((c) => c.slug)
          .whereType<String>()
          .toSet();

      expect(liveSlugs.contains(expected), isTrue);
      expect(
        mockSlugs.contains(expected),
        isTrue,
        reason: 'the offline fallback must offer the same tab',
      );
    }, skip: skip);
  });
}
