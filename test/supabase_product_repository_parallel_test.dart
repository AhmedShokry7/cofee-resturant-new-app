import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          if (pricingStarted && !bothStarted.isCompleted)
            bothStarted.complete();
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
}

/// A fake PostgREST endpoint: records what was asked for and answers with
/// fixed rows, so the repository can be exercised without a network.
class _Catalog {
  _Catalog({
    this.products = const <Map<String, dynamic>>[],
    this.images = const <Map<String, dynamic>>[],
    this.pricing = const <Map<String, dynamic>>[],
    this.failImages = false,
    this.failPricing = false,
    this.onImages,
    this.onPricing,
  });

  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> images;
  final List<Map<String, dynamic>> pricing;
  final bool failImages;
  final bool failPricing;
  final Future<void> Function()? onImages;
  final Future<void> Function()? onPricing;

  final List<Uri> requests = <Uri>[];

  int get productsRequests =>
      requests.where((u) => u.path.endsWith('/products')).length;
  int get imageRequests =>
      requests.where((u) => u.path.endsWith('/product_images')).length;
  int get pricingRequests =>
      requests.where((u) => u.path.endsWith('/branch_product_pricing')).length;
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

    if (url.path.endsWith('/product_images')) {
      if (onImages != null) await onImages!();
      if (failImages) {
        return _response(request, 'image query failed', 500);
      }
      return _response(request, jsonEncode(images), 200);
    }
    if (url.path.endsWith('/branch_product_pricing')) {
      if (onPricing != null) await onPricing!();
      if (failPricing) {
        return _response(request, 'pricing query failed', 500);
      }
      return _response(request, jsonEncode(pricing), 200);
    }
    if (url.path.endsWith('/products')) {
      return _response(request, jsonEncode(products), 200);
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
