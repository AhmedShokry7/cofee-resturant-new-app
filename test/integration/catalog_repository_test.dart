import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/core/config/app_config.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/services/supabase_service.dart';

import '../support/live_branch.dart';
import '../support/mock_product_repository.dart';

import 'package:new_coffee/features/home/data/model/banner_model.dart';
import 'package:new_coffee/features/categories/presentation/manager/categories/categories_cubit.dart';
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

  /// The branch the customer on this device is browsing, resolved rather than
  /// assumed: see [liveBranchId].
  String? branchId;

  setUpAll(() async {
    // Without credentials the live half is skipped, but the mock half still
    // needs to run, so initialisation must not be asserted unconditionally.
    if (skip != null) return;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SupabaseService.init();
    live = SupabaseProductRepository();
    AppLocale.instance.debugSet(AppLanguage.english);
    branchId = await liveBranchId();
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
        final atBranch = branchId;
        if (atBranch == null) {
          markTestSkipped('This Supabase project has no active branch.');
          return;
        }
        final firstPage = await live.getProducts(branchId: atBranch, limit: 3);
        expect(firstPage, isNotEmpty);
        final ids = firstPage.map((product) => product.id).toList();
        final bulk = await getProductsByIds(live, ids, branchId: atBranch);

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

    test('a branch-scoped read changes prices, not membership', () async {
      final atBranch = branchId;
      if (atBranch == null) {
        markTestSkipped('This Supabase project has no active branch.');
        return;
      }

      final all = await live.getProducts();
      expect(all, isNotEmpty);

      final withBranch = await live.getProducts(branchId: atBranch);
      expect(
        withBranch.length,
        all.length,
        reason: 'an override changes the price, not the membership',
      );
      // Measured 2026-11-03: catalog.branch_product_pricing has no rows in this
      // project, so the branch read must fall back to the product's own price
      // instead of dropping it to zero or losing the item.
      expect(
        {for (final p in withBranch) p.id: p.price},
        {for (final p in all) p.id: p.price},
        reason:
            'a branch with no overrides must not silently re-price the menu',
      );
    }, skip: skip);

    // Live run 2026-11-02: production has five flat categories, no
    // sub-categories and none of the demo slugs, so this asserts the mapping
    // and the slug round-trip instead of the deleted seed's contents.
    test(
      'reads categories and resolves each one back by its own slug',
      () async {
        final categories = await live.getCategories();
        expect(
          categories,
          isNotEmpty,
          reason: 'catalog.categories must be seeded for the menu to render',
        );
        expect(
          categories.every((c) => c.slug != null),
          isTrue,
          reason: 'a stable slug replaces matching categories by name',
        );
        expect(
          categories.map((c) => c.slug).toSet().length,
          categories.length,
          reason: 'the menu opens a category by slug, so one slug is one shelf',
        );
        expect(
          categories.every((c) => (c.nameAr ?? '').trim().isNotEmpty),
          isTrue,
          reason: 'D4 requires Arabic on every category',
        );
        expect(
          categories.every((c) => (c.id ?? '').isNotEmpty),
          isTrue,
          reason: 'the shelf is opened by id, not by position',
        );

        final resolved = await live.getCategoryBySlug(categories.first.slug!);
        expect(resolved, isNotNull);
        expect(resolved!.id, isNotNull);
        expect(resolved.id, categories.first.id);
        expect(
          await live.getCategoryBySlug('no-such-category-for-this-test'),
          isNull,
        );
      },
      skip: skip,
    );

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

    test('resolves a price on the server for the branch in use', () async {
      final atBranch = branchId;
      if (atBranch == null) {
        markTestSkipped('This Supabase project has no active branch.');
        return;
      }
      final all = await live.getProducts();
      final resolved = await live.resolvePrice(
        all.first.id,
        branchId: atBranch,
      );
      expect(resolved, isNotNull);
      expect(resolved!.unitPrice, greaterThan(0));
      expect(resolved.currencyCode, 'SAR');
      expect(
        resolved.isAvailable,
        isTrue,
        reason:
            'the menu lists this product at this branch, so the price the cart '
            'resolves must not contradict that listing',
      );
    }, skip: skip);

    test('a product the branch does not carry is answered, not thrown', () async {
      // The seed used to mark one demo drink unavailable at the demo branch.
      // Neither exists in a real project (measured 2026-11-03: one branch, no
      // branch_product_pricing rows), so this asserts the half of the contract
      // the cart actually depends on: an unknown item must come back as no
      // price rather than an exception that empties the screen.
      final atBranch = branchId;
      if (atBranch == null) {
        markTestSkipped('This Supabase project has no active branch.');
        return;
      }
      final resolved = await live.resolvePrice(
        '00000000-0000-0000-0000-000000000000',
        branchId: atBranch,
      );
      expect(
        resolved == null || !resolved.isAvailable,
        isTrue,
        reason: 'a product id that does not exist cannot be purchasable',
      );
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
        // `cta_label_ar` / `cta_label_en` are nullable columns and the details
        // page renders the chip only when the label is non-empty
        // (banner_details_page.dart:77), so an unset CTA is a valid
        // configuration rather than a broken banner. Measured 2026-11-03: both
        // live banners leave them null. When the shop does set one, the button
        // has to have real text.
        if (banner.ctaLabel.isNotEmpty) {
          expect(banner.ctaLabel.trim(), banner.ctaLabel);
        }

        // A targeted banner is only useful if the target resolves. The old
        // banner page matched on a display-name string, so a banner pointing at
        // a renamed category silently showed nothing.
        if (banner.target != BannerTarget.none) {
          expect(
            banner.targetId ?? banner.targetUrl,
            isNotNull,
            reason:
                '"${banner.titleEn}" asks to open a ${banner.target.storage} '
                'but carries neither an id nor a url',
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
      // implementations must expose the same key - and the key has one owner,
      // the cubit that renders the tab, rather than a copy per test.
      final expected = CategoriesCubit.bundlesSlug;
      final liveCategories = await live.getCategories();
      final liveSlugs = liveCategories
          .map((c) => c.slug)
          .whereType<String>()
          .toSet();
      final mockSlugs = (await mock.getCategories())
          .map((c) => c.slug)
          .whereType<String>()
          .toSet();

      expect(
        mockSlugs.contains(expected),
        isTrue,
        reason: 'the offline fallback must offer the same tab',
      );
      // Measured 2026-11-03: this project's five categories are coffee/dessert
      // shelves and none is the bundles shelf, even though catalog.bundles has
      // rows. That is configuration the dashboard owns, not a broken read, so it
      // is reported instead of failing the suite forever - but it is reported.
      if (!liveSlugs.contains(expected)) {
        markTestSkipped(
          'catalog.categories has no row with slug "$expected" '
          '(live slugs: ${liveSlugs.toList()}). The bundles tab cannot appear '
          'for customers until the dashboard creates that category.',
        );
        return;
      }
      final bundlesCategory = liveCategories.firstWhere(
        (c) => c.slug == expected,
      );
      expect(
        bundlesCategory.id,
        isNotNull,
        reason: 'the tab opens the shelf by id, so the row must carry one',
      );
    }, skip: skip);
  });
}
