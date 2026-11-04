import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/features/menu/data/product_options.dart';
import 'package:new_coffee/features/menu/data/repositories/supabase_product_repository.dart';

/// Deterministic cover for the catalogue read in
/// `SupabaseProductRepository.getProducts`.
///
/// The repository talks to PostgREST through a plain `http.Client`, so a
/// `MockClient` can stand in for the network. That makes it possible to
/// assert three things that a live test cannot: how many requests the method
/// issues, what each request is parameterised with, and that the two
/// follow-up requests are genuinely in flight at the same time.
///
/// No database and no network are touched here.
void main() {
  const branch = '00000000-0000-4000-8000-000000000101';

  List<Map<String, dynamic>> productRows() => <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'p1',
      'category_id': 'c1',
      'sku': 'CF-1',
      'slug': 'latte',
      'name_ar': 'لاتيه',
      'name_en': 'Latte',
      'description_ar': 'وصف اللاتيه',
      'description_en': 'Latte description',
      'base_price': 20,
      'compare_at_price': null,
      'image_url': 'https://img.test/p1.png',
      'is_featured': true,
      'prep_minutes': 3,
      'category_slug': 'hot-coffee',
      'category_name_ar': 'قهوة ساخنة',
      'category_name_en': 'Hot Coffee',
      'related_product_ids': <String>['p2'],
    },
    <String, dynamic>{
      'id': 'p2',
      'category_id': 'c1',
      'sku': 'CF-2',
      'slug': 'cappuccino',
      'name_ar': 'كابتشينو',
      'name_en': 'Cappuccino',
      'description_ar': 'وصف الكابتشينو',
      'description_en': 'Cappuccino description',
      'base_price': 30,
      'compare_at_price': 36,
      'image_url': 'https://img.test/p2.png',
      'is_featured': false,
      'prep_minutes': 4,
      'category_slug': 'hot-coffee',
      'category_name_ar': 'قهوة ساخنة',
      'category_name_en': 'Hot Coffee',
      'related_product_ids': <String>[],
    },
    <String, dynamic>{
      'id': 'p3',
      'category_id': 'c2',
      'sku': 'CF-3',
      'slug': 'cola',
      'name_ar': 'كولا',
      'name_en': 'Cola',
      'description_ar': 'وصف الكولا',
      'description_en': 'Cola description',
      'base_price': 40,
      'compare_at_price': null,
      'image_url': 'https://img.test/p3.png',
      'is_featured': false,
      'prep_minutes': 1,
      'category_slug': 'soft-drinks',
      'category_name_ar': 'مشروبات باردة',
      'category_name_en': 'Soft Drinks',
      'related_product_ids': <String>[],
    },
  ];

  List<Map<String, dynamic>> imageRows() => <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'i1',
      'product_id': 'p1',
      'image_url': 'https://img.test/p1-a.png',
      'alt_ar': null,
      'alt_en': null,
      'is_primary': false,
      'sort_order': 1,
    },
    <String, dynamic>{
      'id': 'i2',
      'product_id': 'p1',
      'image_url': 'https://img.test/p1-b.png',
      'alt_ar': null,
      'alt_en': null,
      'is_primary': true,
      'sort_order': 2,
      'fit': 'contain',
      'alignment': 'bottomRight',
    },
    <String, dynamic>{
      'id': 'i3',
      'product_id': 'p2',
      'image_url': 'https://img.test/p2.png',
      'alt_ar': null,
      'alt_en': null,
      'is_primary': true,
      'sort_order': 1,
    },
  ];

  List<Map<String, dynamic>> pricingRows() => <Map<String, dynamic>>[
    <String, dynamic>{
      'product_id': 'p1',
      'price_override': 15,
      'is_available': true,
      'unavailable_reason': null,
    },
    <String, dynamic>{
      'product_id': 'p3',
      'price_override': null,
      'is_available': false,
      'unavailable_reason': 'sold out',
    },
  ];

  group('getProducts', () {
    test(
      'returns the products in catalogue order with the branch price applied',
      () async {
        final catalog = _Catalog(
          products: productRows(),
          images: imageRows(),
          pricing: pricingRows(),
        );

        final items = await catalog.repository().getProducts(branchId: branch);

        expect(items.map((p) => p.id).toList(), <String>[
          'p1',
          'p2',
          'p3',
        ], reason: 'the order must be the one the catalogue query returned');
        expect(items.map((p) => p.nameEn).toList(), <String>[
          'Latte',
          'Cappuccino',
          'Cola',
        ]);
        expect(items[0].price, 15, reason: 'the branch override wins');
        expect(items[1].price, 30, reason: 'no override keeps the base price');
        expect(
          items[2].price,
          40,
          reason: 'a null override keeps the base price',
        );
        expect(items[0].descriptionEn, 'Latte description');
        expect(items[0].isFeatured, isTrue);
        expect(
          items[1].oldPrice,
          36,
          reason: 'compare_at_price is the old price',
        );
      },
    );

    test('keeps the catalogue fields the copy used to drop', () async {
      // The catalogue query returns the category slug, the preparation time,
      // the SKU and the related product ids, and the product is copied twice
      // on the way out of getProducts: once for the gallery and once for the
      // branch price. Every field the copy carries has to survive both
      // copies, otherwise the recommendation rule and "Goes well with" see
      // an empty product.
      final catalog = _Catalog(
        products: productRows(),
        images: imageRows(),
        pricing: pricingRows(),
      );

      final items = await catalog.repository().getProducts(branchId: branch);

      expect(items.first.categorySlug, 'hot-coffee');
      expect(items.first.prepMinutes, 3);
      expect(items.first.sku, 'CF-1');
      expect(items.first.relatedProductIds, <String>['p2']);
    });

    test('binds every image to the product it belongs to', () async {
      final catalog = _Catalog(
        products: productRows(),
        images: imageRows(),
        pricing: pricingRows(),
      );

      final items = await catalog.repository().getProducts(branchId: branch);

      expect(items[0].imageUrls, <String>[
        'https://img.test/p1-a.png',
        'https://img.test/p1-b.png',
      ], reason: 'images keep the order the image query returned');
      expect(
        items[0].primaryImageUrl,
        'https://img.test/p1-b.png',
        reason: 'the image flagged is_primary wins',
      );
      expect(items[0].isPrimaryImageAvailable, isTrue);
      expect(items[1].imageUrls, <String>['https://img.test/p2.png']);
      expect(items[1].primaryImageUrl, 'https://img.test/p2.png');
      expect(
        items[2].imageUrls,
        isEmpty,
        reason: 'a product without image rows has no gallery',
      );
      expect(
        items[2].primaryImageUrl,
        'https://img.test/p3.png',
        reason: 'the product image is the fallback',
      );
    });

    test(
      'asks the follow-up queries for exactly the products it received',
      () async {
        final catalog = _Catalog(
          products: productRows(),
          images: imageRows(),
          pricing: pricingRows(),
        );

        await catalog.repository().getProducts(branchId: branch);

        final imageRequest = catalog.requestEndingWith('/product_images');
        final pricingRequest = catalog.requestEndingWith(
          '/branch_product_pricing',
        );
        expect(imageRequest, isNotNull);
        expect(pricingRequest, isNotNull);
        for (final id in <String>['p1', 'p2', 'p3']) {
          expect(imageRequest!.query, contains(id));
          expect(pricingRequest!.query, contains(id));
        }
        expect(pricingRequest!.query, contains(branch));
      },
    );

    test('does not request branch prices when no branch is selected', () async {
      final catalog = _Catalog(
        products: productRows(),
        images: imageRows(),
        pricing: pricingRows(),
      );

      final items = await catalog.repository().getProducts();

      expect(
        catalog.pricingRequests,
        0,
        reason: 'a read without a branch must not ask for branch prices',
      );
      expect(catalog.imageRequests, 1);
      expect(catalog.productsRequests, 1);
      expect(catalog.totalRequests, 2);
      expect(items[0].price, 20, reason: 'the base price is used');
    });

    test(
      'issues only the catalogue request when there are no products',
      () async {
        final catalog = _Catalog(products: <Map<String, dynamic>>[]);

        final items = await catalog.repository().getProducts(branchId: branch);

        expect(items, isEmpty);
        expect(catalog.productsRequests, 1);
        expect(
          catalog.imageRequests,
          0,
          reason: 'an empty catalogue must not trigger the follow-up queries',
        );
        expect(catalog.pricingRequests, 0);
        expect(catalog.totalRequests, 1);
      },
    );

    test('surfaces the failure of the image request', () async {
      final catalog = _Catalog(
        products: productRows(),
        images: imageRows(),
        pricing: pricingRows(),
        failImages: true,
      );

      await expectLater(
        catalog.repository().getProducts(branchId: branch),
        throwsA(isA<Object>()),
      );
    });

    test('surfaces the failure of the branch price request', () async {
      final catalog = _Catalog(
        products: productRows(),
        images: imageRows(),
        pricing: pricingRows(),
        failPricing: true,
      );

      await expectLater(
        catalog.repository().getProducts(branchId: branch),
        throwsA(isA<Object>()),
      );
    });

    test('surfaces one error when both follow-up requests fail', () async {
      final catalog = _Catalog(
        products: productRows(),
        images: imageRows(),
        pricing: pricingRows(),
        failImages: true,
        failPricing: true,
      );

      await expectLater(
        catalog.repository().getProducts(branchId: branch),
        throwsA(isA<Object>()),
      );
      // The failure must be reported once, not twice: an unhandled sibling
      // rejection would surface as a second, stray asynchronous error.
      expect(catalog.totalRequests, 3);
    });

    test('has the image and the branch price request in flight together', () async {
      // Deterministic proof of concurrency: each follow-up request waits until
      // the other one has started. If the method issued them one after the
      // other, the first one would wait forever and the request would fail
      // with the message below instead of hanging the whole suite.
      final bothStarted = Completer<void>();
      var imagesStarted = false;
      var pricingStarted = false;

      Future<void> waitForTheOther(String which) async {
        if (which == 'images') {
          imagesStarted = true;
          if (pricingStarted && !bothStarted.isCompleted) {
            bothStarted.complete();
          }
        } else {
          pricingStarted = true;
          if (imagesStarted && !bothStarted.isCompleted) bothStarted.complete();
        }
        await bothStarted.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw StateError(
            'the image and the branch price request were not in flight together',
          ),
        );
      }

      final catalog = _Catalog(
        products: productRows(),
        images: imageRows(),
        pricing: pricingRows(),
        onImages: () => waitForTheOther('images'),
        onPricing: () => waitForTheOther('pricing'),
      );

      final items = await catalog.repository().getProducts(branchId: branch);

      expect(items, hasLength(3));
      expect(catalog.imageRequests, 1);
      expect(catalog.pricingRequests, 1);
      expect(catalog.totalRequests, 3);
    });
  });

  group('getById', () {
    test(
      'shows the primary picture with the settings of the dashboard',
      () async {
        final catalog = _Catalog(
          products: productRows(),
          images: imageRows(),
          pricing: pricingRows(),
        );

        final product = await catalog.repository().getById(
          'p1',
          branchId: branch,
        );

        expect(product, isNotNull);
        expect(product!.primaryImageUrl, 'https://img.test/p1-b.png');
        expect(product.imageFit, 'contain');
        expect(product.imageAlignment, 'bottomRight');
      },
    );
  });

  group('sort_order reads', () {
    test('asks PostgREST for the banner order the dashboard sets', () async {
      // `sort_order` counts up from 0, but the query builder defaults to
      // DESCENDING, so a banner row left at its default arrived last and the
      // carousel opened on the wrong picture. The request has to say `asc`.
      final catalog = _Catalog();

      await catalog.repository().getBanners();

      final banners = catalog.requestEndingWith('/banners');
      expect(banners, isNotNull);
      expect(
        banners!.queryParameters['order'],
        startsWith('sort_order.asc'),
        reason: 'the carousel follows the admin order, lowest first',
      );
    });

    test('asks for the same order for categories and bundles', () async {
      final catalog = _Catalog();

      await catalog.repository().getCategories();
      await catalog.repository().getBundles(branchId: branch);

      for (final path in <String>['/categories', '/bundles']) {
        final request = catalog.requestEndingWith(path);
        expect(request, isNotNull, reason: '$path was queried');
        expect(
          request!.queryParameters['order'],
          startsWith('sort_order.asc'),
          reason: '$path must not inherit the descending default',
        );
      }
    });
  });

  group('banner links', () {
    test('reads both link tables for the banner it was given', () async {
      final catalog = _Catalog(
        bannerProducts: <Map<String, dynamic>>[
          <String, dynamic>{'product_id': 'p9', 'sort_order': 0},
        ],
        bannerCategories: <Map<String, dynamic>>[
          <String, dynamic>{'category_id': 'c2', 'sort_order': 0},
        ],
      );

      final links = await catalog.repository().getBannerLinks('b1');

      expect(links.productIds, <String>['p9']);
      expect(links.categoryIds, <String>['c2']);
      for (final path in <String>['/banner_products', '/banner_categories']) {
        final request = catalog.requestEndingWith(path);
        expect(request, isNotNull, reason: '$path was read');
        expect(request!.queryParameters['banner_id'], 'eq.b1');
        expect(
          request.queryParameters['order'],
          startsWith('sort_order.asc'),
          reason: '$path keeps the order the admin set',
        );
      }
    });

    test('a database without the link tables answers no links', () async {
      // Migration 222 may not be applied to the database this build talks to.
      // The banner page then shows the row behind target_id, which is the whole
      // behaviour it had before, instead of failing.
      final catalog = _Catalog(bannerLinksMissing: true);

      final links = await catalog.repository().getBannerLinks('b1');

      expect(links.isEmpty, isTrue);
    });
  });

  group('getWithOptions', () {
    test('reads the gallery once for the product it already loaded', () async {
      final catalog = _Catalog(
        products: productRows(),
        images: imageRows(),
        pricing: pricingRows(),
      );

      final loaded = await catalog.repository().getWithOptions('p1');

      expect(loaded, isNotNull);
      expect(
        catalog.imageRequests,
        1,
        reason: 'the detail read reused a second gallery query for the same product',
      );
      expect(loaded!.images, isNotEmpty);
    });

    test('holds the row, the gallery, the branch price and the bindings open '
        'at the same time', () async {
      // Each of the four waits until all four have started. Read one after
      // another and the first would time out into a StateError instead of
      // quietly passing.
      final stage = _InFlightBarrier(4);
      final catalog = _Catalog(
        products: productRows(),
        images: imageRows(),
        pricing: pricingRows(),
        hooks: <String, Future<void> Function()>{
          'products': stage.hookFor('products'),
          'product_images': stage.hookFor('product_images'),
          'branch_product_pricing': stage.hookFor('branch_product_pricing'),
          'product_option_groups_effective': stage.hookFor(
            'product_option_groups_effective',
          ),
        },
      );

      final loaded = await catalog.repository().getWithOptions(
        'p1',
        branchId: branch,
      );

      expect(loaded, isNotNull);
      expect(loaded!.product.price, 15, reason: 'the branch override applied');
      expect(
        catalog.totalRequests,
        4,
        reason:
            'a product with no options '
            'stops after the first stage',
      );
    });

    test(
      'asks for the option groups and their values in one round trip',
      () async {
        final firstStage = _InFlightBarrier(4);
        final secondStage = _InFlightBarrier(3);
        final catalog = _Catalog(
          products: productRows(),
          images: imageRows(),
          pricing: pricingRows(),
          links: <Map<String, dynamic>>[
            <String, dynamic>{
              'group_id': 'g1',
              'sort_order': 0,
              'is_required': true,
            },
          ],
          optionGroups: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'g1',
              'code': 'size',
              'name_ar': 'الحجم',
              'name_en': 'Size',
              'selection_type': 'single',
              'min_select': 1,
              'max_select': 1,
              'is_required': true,
              'sort_order': 0,
              'is_active': true,
            },
          ],
          optionValues: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'v1',
              'group_id': 'g1',
              'code': 'medium',
              'name_ar': 'وسط',
              'name_en': 'Medium',
              'price_delta': 0,
              'short_label': null,
              'is_default': true,
              'sort_order': 0,
              'is_active': true,
            },
            <String, dynamic>{
              'id': 'v2',
              'group_id': 'g1',
              'code': 'large',
              'name_ar': 'كبير',
              'name_en': 'Large',
              'price_delta': 4,
              'short_label': null,
              'is_default': false,
              'sort_order': 1,
              'is_active': true,
            },
          ],
          hooks: <String, Future<void> Function()>{
            'products': firstStage.hookFor('products'),
            'product_images': firstStage.hookFor('product_images'),
            'branch_product_pricing': firstStage.hookFor(
              'branch_product_pricing',
            ),
            'product_option_groups_effective': firstStage.hookFor(
              'product_option_groups_effective',
            ),
            'option_groups': secondStage.hookFor('option_groups'),
            'option_values': secondStage.hookFor('option_values'),
            'product_option_value_pricing': secondStage.hookFor(
              'product_option_value_pricing',
            ),
          },
        );

        final loaded = await catalog.repository().getWithOptions(
          'p1',
          branchId: branch,
        );

        expect(catalog.optionGroupRequests, 1);
        expect(catalog.optionValueRequests, 1);
        expect(catalog.optionPricingRequests, 1);
        expect(
          catalog.totalRequests,
          7,
          reason: 'two stages, not six round trips',
        );
        final group = loaded!.groups.single;
        expect(group.values.map((v) => v.id).toList(), <String>['v1', 'v2']);
      },
    );

    test(
      'answers nothing when the product row is gone, having already sent the '
      'reads it cannot use',
      () async {
        // The gallery and the branch price are keyed by the id we hold, so they
        // go out with the product query. An empty product row discards them and
        // reports the product as missing.
        final catalog = _Catalog(images: imageRows(), pricing: pricingRows());

        final loaded = await catalog.repository().getWithOptions(
          'p1',
          branchId: branch,
        );

        expect(loaded, isNull);
        expect(catalog.imageRequests, 1);
        expect(catalog.pricingRequests, 1);
        expect(catalog.totalRequests, 4);
      },
    );

    test(
      'reports the gallery failure once when the product row is also missing',
      () async {
        // Both rejections land while nothing is listening yet. Attaching the
        // three reads to one Future.wait is what stops the gallery error from
        // surfacing as a stray unhandled asynchronous error beside the call.
        final catalog = _Catalog(
          images: imageRows(),
          pricing: pricingRows(),
          failImages: true,
        );

        await expectLater(
          catalog.repository().getWithOptions('p1', branchId: branch),
          throwsA(isA<Object>()),
        );
      },
    );
  });

  group('option value pricing override (229)', () {
    final sizeGroup = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'g1',
        'code': 'size',
        'name_ar': 'الحجم',
        'name_en': 'Size',
        'selection_type': 'single',
        'min_select': 1,
        'max_select': 1,
        'is_required': true,
        'sort_order': 0,
        'is_active': true,
      },
    ];
    final sizeValues = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'v1',
        'group_id': 'g1',
        'code': 'small',
        'name_ar': 'صغير',
        'name_en': 'Small',
        'price_delta': 0,
        'short_label': null,
        'is_default': true,
        'sort_order': 0,
        'is_active': true,
      },
      <String, dynamic>{
        'id': 'v2',
        'group_id': 'g1',
        'code': 'large',
        'name_ar': 'كبير',
        'name_en': 'Large',
        'price_delta': 4,
        'short_label': null,
        'is_default': false,
        'sort_order': 1,
        'is_active': true,
      },
    ];
    final singleLink = <Map<String, dynamic>>[
      <String, dynamic>{
        'group_id': 'g1',
        'sort_order': 0,
        'is_required': true,
      },
    ];

    test('getWithOptions resolves the value to the override it carries', () async {
      // Migration 229 lets the dashboard pin one size's delta for one product.
      // The local estimate must add the same number the server charges, so the
      // override wins over the group default on the value the app holds.
      final catalog = _Catalog(
        products: productRows(),
        images: imageRows(),
        links: singleLink,
        optionGroups: sizeGroup,
        optionValues: sizeValues,
        optionPricing: <Map<String, dynamic>>[
          <String, dynamic>{
            'product_id': 'p1',
            'value_id': 'v2',
            'price_delta': 9,
          },
        ],
      );

      final loaded = await catalog.repository().getWithOptions('p1');
      final group = loaded!.groups.single;
      final large = group.values.firstWhere((v) => v.id == 'v2');
      final small = group.values.firstWhere((v) => v.id == 'v1');

      expect(
        large.priceDelta,
        9,
        reason: 'the override replaces the group default',
      );
      expect(
        small.priceDelta,
        0,
        reason: 'a value with no override keeps its own delta',
      );

      var selection = OptionSelection.defaultsFor(loaded.groups);
      selection = selection.toggle(loaded.groups, group.id, 'v2');
      expect(selection.deltaOf(loaded.groups), 9);
      expect(
        estimateUnitPrice(loaded.product, loaded.groups, selection),
        loaded.product.price + 9,
        reason: 'the local estimate uses the override',
      );
    });

    test('getWithOptions keeps the group default when no override exists', () async {
      final catalog = _Catalog(
        products: productRows(),
        images: imageRows(),
        links: singleLink,
        optionGroups: sizeGroup,
        optionValues: sizeValues,
      );

      final loaded = await catalog.repository().getWithOptions('p1');
      final large = loaded!.groups.single.values.firstWhere((v) => v.id == 'v2');

      expect(
        large.priceDelta,
        4,
        reason: 'an absent override leaves the value default untouched',
      );
      expect(
        catalog.optionPricingRequests,
        1,
        reason: 'the product is still read, it just comes back empty',
      );
    });

    test(
      'getOptionsByProduct resolves each product from one pricing query',
      () async {
        // Two products share the group, but only p1 has an override. The batch
        // read has to price each from its own rows in a single request, never
        // one per product.
        final catalog = _Catalog(
          links: <Map<String, dynamic>>[
            <String, dynamic>{
              'product_id': 'p1',
              'group_id': 'g1',
              'sort_order': 0,
              'is_required': true,
            },
            <String, dynamic>{
              'product_id': 'p2',
              'group_id': 'g1',
              'sort_order': 0,
              'is_required': true,
            },
          ],
          optionGroups: sizeGroup,
          optionValues: sizeValues,
          optionPricing: <Map<String, dynamic>>[
            <String, dynamic>{
              'product_id': 'p1',
              'value_id': 'v2',
              'price_delta': 9,
            },
          ],
        );

        final byProduct = await catalog.repository().getOptionsByProduct([
          'p1',
          'p2',
        ]);

        final large1 = byProduct['p1']!.single.values.firstWhere(
          (v) => v.id == 'v2',
        );
        final large2 = byProduct['p2']!.single.values.firstWhere(
          (v) => v.id == 'v2',
        );

        expect(large1.priceDelta, 9, reason: 'p1 carries its override');
        expect(large2.priceDelta, 4, reason: 'p2 keeps the group default');
        expect(
          catalog.optionPricingRequests,
          1,
          reason: 'the whole batch is one query, not one per product',
        );
      },
    );
  });
}

/// Lets a test prove several requests are in flight at once: every participant
/// waits here until all of them have arrived, so a serial implementation
/// produces a [StateError] rather than a silent pass.
class _InFlightBarrier {
  _InFlightBarrier(this.expected);

  final int expected;
  final Set<String> _started = <String>{};
  final Completer<void> _gate = Completer<void>();

  Future<void> Function() hookFor(String name) => () async {
    _started.add(name);
    if (_started.length == expected && !_gate.isCompleted) {
      _gate.complete();
    }
    await _gate.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw StateError(
        'only $_started of $expected started: the reads ran one after another',
      ),
    );
  };
}

/// A fake PostgREST endpoint: records what was asked for and answers with
/// fixed rows, so the repository can be exercised without a network.
class _Catalog {
  _Catalog({
    this.products = const <Map<String, dynamic>>[],
    this.images = const <Map<String, dynamic>>[],
    this.pricing = const <Map<String, dynamic>>[],
    this.links = const <Map<String, dynamic>>[],
    this.optionGroups = const <Map<String, dynamic>>[],
    this.optionValues = const <Map<String, dynamic>>[],
    this.optionPricing = const <Map<String, dynamic>>[],
    this.failImages = false,
    this.failPricing = false,
    this.onImages,
    this.onPricing,
    this.hooks = const <String, Future<void> Function()>{},
    this.bannerProducts = const <Map<String, dynamic>>[],
    this.bannerCategories = const <Map<String, dynamic>>[],
    this.bannerLinksMissing = false,
  });

  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> pricing;
  final List<Map<String, dynamic>> links;
  final List<Map<String, dynamic>> optionGroups;
  final List<Map<String, dynamic>> optionValues;
  final List<Map<String, dynamic>> optionPricing;
  final bool failImages;
  final bool failPricing;
  final Future<void> Function()? onImages;
  final Future<void> Function()? onPricing;

  /// Waits run before the answer is sent, keyed by the last path segment. Used
  /// to prove several reads are in flight at once.
  final Map<String, Future<void> Function()> hooks;

  final List<Map<String, dynamic>> bannerProducts;
  final List<Map<String, dynamic>> bannerCategories;
  final bool bannerLinksMissing;

  final List<Uri> requests = <Uri>[];

  int get productsRequests =>
      requests.where((u) => u.path.endsWith('/products')).length;
  int get imageRequests =>
      requests.where((u) => u.path.endsWith('/product_images')).length;
  int get pricingRequests =>
      requests.where((u) => u.path.endsWith('/branch_product_pricing')).length;
  int get linkRequests => requests
      .where((u) => u.path.endsWith('/product_option_groups_effective'))
      .length;
  int get optionGroupRequests =>
      requests.where((u) => u.path.endsWith('/option_groups')).length;
  int get optionValueRequests =>
      requests.where((u) => u.path.endsWith('/option_values')).length;
  int get optionPricingRequests =>
      requests.where((u) => u.path.endsWith('/product_option_value_pricing'))
          .length;
  int get totalRequests => requests.length;

  Uri? requestEndingWith(String suffix) {
    for (final uri in requests) {
      if (uri.path.endsWith(suffix)) return uri;
    }
    return null;
  }

  SupabaseProductRepository repository() => SupabaseProductRepository(
    SupabaseClient(
      'https://catalog.test',
      'anon-key',
      httpClient: MockClient(_handle),
    ),
  );

  Future<http.Response> _handle(http.BaseRequest request) async {
    final url = request.url;
    requests.add(url);

    final name = url.pathSegments.last;
    if (name == 'product_images' && onImages != null) {
      await onImages!();
    } else if (name == 'branch_product_pricing' && onPricing != null) {
      await onPricing!();
    } else if (hooks.containsKey(name)) {
      await hooks[name]!();
    }

    if (url.path.endsWith('/product_images')) {
      if (failImages) {
        return _response(request, 'image query failed', 500);
      }
      return _response(request, jsonEncode(images), 200);
    }
    if (url.path.endsWith('/branch_product_pricing')) {
      if (failPricing) {
        return _response(request, 'pricing query failed', 500);
      }
      return _response(request, jsonEncode(pricing), 200);
    }
    if (url.path.endsWith('/products')) {
      return _response(request, jsonEncode(products), 200);
    }
    if (url.path.endsWith('/product_option_groups_effective')) {
      return _response(request, jsonEncode(links), 200);
    }
    if (url.path.endsWith('/option_groups')) {
      return _response(request, jsonEncode(optionGroups), 200);
    }
    if (url.path.endsWith('/option_values')) {
      return _response(request, jsonEncode(optionValues), 200);
    }
    if (url.path.endsWith('/product_option_value_pricing')) {
      return _response(request, jsonEncode(optionPricing), 200);
    }
    if (url.path.endsWith('/banner_products') ||
        url.path.endsWith('/banner_categories')) {
      if (bannerLinksMissing) {
        // What PostgREST answers for a table the API does not know: the
        // database where migration 222 has not been applied yet.
        return _response(
          request,
          '{"code":"PGRST205","details":null,"hint":null,'
          '"message":"Could not find the \'${url.pathSegments.last}\' table '
          'or view in the schema cache"}',
          404,
        );
      }
      final rows = url.path.endsWith('/banner_products')
          ? bannerProducts
          : bannerCategories;
      return _response(request, jsonEncode(rows), 200);
    }
    return _response(request, '[]', 200);
  }

  /// PostgREST reads `response.request`, so the fake response has to carry
  /// the request that produced it. Without it the client fails before it can
  /// look at the body.
  static http.Response _response(
    http.BaseRequest request,
    String body,
    int statusCode,
  ) => http.Response(
    body,
    statusCode,
    request: request,
    headers: <String, String>{'content-type': 'application/json'},
  );
}
