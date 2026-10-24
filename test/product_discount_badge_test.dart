import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/features/menu/data/repositories/supabase_product_repository.dart';

/// The badge must state a discount that really exists.
///
/// The percentage used to be derived from two prices, and the old price came
/// from the admin's compare-at price. A product with a compare-at price and no
/// discount announced a percentage that nobody was ever charged.
void main() {
  const branch = '00000000-0000-4000-8000-000000000101';

  final activeWindow = <String, dynamic>{
    'discount_starts_at': DateTime.now()
        .subtract(const Duration(hours: 1))
        .toIso8601String(),
    'discount_ends_at': DateTime.now()
        .add(const Duration(hours: 1))
        .toIso8601String(),
  };

  Map<String, dynamic> productJson({
    double? compareAtPrice,
    double? discountPercentage,
    Map<String, dynamic>? window,
  }) =>
      <String, dynamic>{
        'id': 'p1',
        'category_id': 'c1',
        'sku': 'CF-1',
        'slug': 'latte',
        'name_ar': 'Latte',
        'name_en': 'Latte',
        'description_ar': '',
        'description_en': '',
        'base_price': 100,
        'compare_at_price': compareAtPrice,
        'image_url': 'https://img.test/p1.png',
        'is_featured': true,
        'prep_minutes': 3,
        'category_slug': 'hot-coffee',
        'category_name_ar': 'Coffee',
        'category_name_en': 'Hot Coffee',
        'related_product_ids': <String>[],
        'discount_percentage': discountPercentage,
        ...?window,
      };

  test('a compare-at price is not a discount', () async {
    final repository = SupabaseProductRepository(
      SupabaseClient(
        'https://catalog.test',
        'anon-key',
        httpClient: MockClient((request) async {
          final uri = request.url;
          if (uri.path.endsWith('/products')) {
            return http.Response(
                jsonEncode(<Map<String, dynamic>>[
                  productJson(compareAtPrice: 120),
                ]),
                200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          if (uri.path.endsWith('/product_images')) {
            return http.Response('[]', 200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          if (uri.path.endsWith('/branch_product_pricing')) {
            return http.Response('[]', 200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('[]', 200,
              request: request, headers: {'content-type': 'application/json'});
        }),
      ),
    );

    final products = await repository.getProducts(branchId: branch);
    expect(products, hasLength(1));
    // The price is not reduced, so nothing may claim that it is.
    expect(products.first.price, closeTo(100, 0.001));
    expect(products.first.appliedDiscountPercentage, isNull);
    expect(products.first.hasDiscount, isFalse);
    // The compare-at price is still shown as a reference price.
    expect(products.first.oldPrice, closeTo(120, 0.001));
    expect(products.first.hasOldPrice, isTrue);
  });

  test('the badge carries the general discount that is applied', () async {
    final repository = SupabaseProductRepository(
      SupabaseClient(
        'https://catalog.test',
        'anon-key',
        httpClient: MockClient((request) async {
          final uri = request.url;
          if (uri.path.endsWith('/products')) {
            return http.Response(
                jsonEncode(<Map<String, dynamic>>[
                  productJson(
                    compareAtPrice: 130,
                    discountPercentage: 10,
                    window: activeWindow,
                  ),
                ]),
                200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          if (uri.path.endsWith('/product_images')) {
            return http.Response('[]', 200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          if (uri.path.endsWith('/branch_product_pricing')) {
            return http.Response('[]', 200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('[]', 200,
              request: request, headers: {'content-type': 'application/json'});
        }),
      ),
    );

    final products = await repository.getProducts(branchId: branch);
    expect(products.first.price, closeTo(90, 0.001));
    expect(products.first.appliedDiscountPercentage, closeTo(10, 0.001));
    expect(products.first.hasDiscount, isTrue);
    // The price before the discount is the one the customer would have paid,
    // not the compare-at price.
    expect(products.first.oldPrice, closeTo(100, 0.001));
  });

  test('the badge carries the branch discount, not the general one', () async {
    final repository = SupabaseProductRepository(
      SupabaseClient(
        'https://catalog.test',
        'anon-key',
        httpClient: MockClient((request) async {
          final uri = request.url;
          if (uri.path.endsWith('/products')) {
            return http.Response(
                jsonEncode(<Map<String, dynamic>>[
                  productJson(
                    discountPercentage: 10,
                    window: activeWindow,
                  ),
                ]),
                200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          if (uri.path.endsWith('/product_images')) {
            return http.Response('[]', 200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          if (uri.path.endsWith('/branch_product_pricing')) {
            return http.Response(
                jsonEncode(<Map<String, dynamic>>[
                  <String, dynamic>{
                    'product_id': 'p1',
                    'price_override': null,
                    'is_available': true,
                    'unavailable_reason': null,
                    'discount_percentage': 20,
                    ...activeWindow,
                    'use_general_discount': true,
                  },
                ]),
                200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('[]', 200,
              request: request, headers: {'content-type': 'application/json'});
        }),
      ),
    );

    final products = await repository.getProducts(branchId: branch);
    expect(products.first.price, closeTo(80, 0.001));
    expect(products.first.appliedDiscountPercentage, closeTo(20, 0.001));
    expect(products.first.hasDiscount, isTrue);
  });

  test('an expired discount window leaves the product without a discount',
      () async {
    final repository = SupabaseProductRepository(
      SupabaseClient(
        'https://catalog.test',
        'anon-key',
        httpClient: MockClient((request) async {
          final uri = request.url;
          if (uri.path.endsWith('/products')) {
            return http.Response(
                jsonEncode(<Map<String, dynamic>>[
                  productJson(
                    discountPercentage: 10,
                    window: <String, dynamic>{
                      'discount_starts_at': DateTime.now()
                          .subtract(const Duration(hours: 2))
                          .toIso8601String(),
                      'discount_ends_at': DateTime.now()
                          .subtract(const Duration(hours: 1))
                          .toIso8601String(),
                    },
                  ),
                ]),
                200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          if (uri.path.endsWith('/product_images')) {
            return http.Response('[]', 200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          if (uri.path.endsWith('/branch_product_pricing')) {
            return http.Response('[]', 200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('[]', 200,
              request: request, headers: {'content-type': 'application/json'});
        }),
      ),
    );

    final products = await repository.getProducts(branchId: branch);
    expect(products.first.price, closeTo(100, 0.001));
    expect(products.first.hasDiscount, isFalse);
    expect(products.first.appliedDiscountPercentage, isNull);
  });

  test('the bulk read carries the discount the server applied', () async {
    final repository = SupabaseProductRepository(
      SupabaseClient(
        'https://catalog.test',
        'anon-key',
        httpClient: MockClient((request) async {
          final uri = request.url;
          if (uri.path.endsWith('/rpc/catalog_products_by_ids')) {
            return http.Response(
                jsonEncode(<Map<String, dynamic>>[
                  <String, dynamic>{
                    'product': productJson(compareAtPrice: 130),
                    'images': <Map<String, dynamic>>[],
                    'effective_price': 80,
                    'regular_price': 100,
                    'discount_percentage': 20,
                  },
                ]),
                200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('[]', 200,
              request: request, headers: {'content-type': 'application/json'});
        }),
      ),
    );

    final products = await repository.getByIds(['p1'], branchId: branch);
    expect(products.first.price, closeTo(80, 0.001));
    expect(products.first.appliedDiscountPercentage, closeTo(20, 0.001));
    expect(products.first.hasDiscount, isTrue);
    expect(products.first.oldPrice, closeTo(100, 0.001));
  });

  test('the search row carries the discount the server applied', () async {
    final repository = SupabaseProductRepository(
      SupabaseClient(
        'https://catalog.test',
        'anon-key',
        httpClient: MockClient((request) async {
          final uri = request.url;
          if (uri.path.endsWith('/rpc/search_products')) {
            return http.Response(
                jsonEncode(<Map<String, dynamic>>[
                  <String, dynamic>{
                    ...productJson(),
                    'effective_price': 80,
                    'regular_price': 100,
                    'discount_percentage': 20,
                    'rank': 1,
                    'total_count': 1,
                  },
                ]),
                200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('[]', 200,
              request: request, headers: {'content-type': 'application/json'});
        }),
      ),
    );

    final products = await repository.search('latte', branchId: branch);
    expect(products.first.price, closeTo(80, 0.001));
    expect(products.first.appliedDiscountPercentage, closeTo(20, 0.001));
    expect(products.first.hasDiscount, isTrue);
    expect(products.first.oldPrice, closeTo(100, 0.001));
  });

  test('the featured row carries the discount the server applied', () async {
    final repository = SupabaseProductRepository(
      SupabaseClient(
        'https://catalog.test',
        'anon-key',
        httpClient: MockClient((request) async {
          final uri = request.url;
          if (uri.path.endsWith('/rpc/get_featured')) {
            return http.Response(
                jsonEncode(<Map<String, dynamic>>[
                  <String, dynamic>{
                    'product_id': 'p1',
                    'name_ar': 'Latte',
                    'name_en': 'Latte',
                    'image_url': 'https://img.test/p1.png',
                    'effective_price': 80,
                    'regular_price': 100,
                    'discount_percentage': 20,
                    'source': 'manual',
                  },
                ]),
                200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('[]', 200,
              request: request, headers: {'content-type': 'application/json'});
        }),
      ),
    );

    final featured = await repository.getFeatured(branchId: branch);
    expect(featured.first.effectivePrice, closeTo(80, 0.001));
    expect(featured.first.discountPercentage, closeTo(20, 0.001));
    expect(featured.first.hasDiscount, isTrue);
    expect(featured.first.regularPrice, closeTo(100, 0.001));
  });

  test('a featured row without a discount claims none', () async {
    final repository = SupabaseProductRepository(
      SupabaseClient(
        'https://catalog.test',
        'anon-key',
        httpClient: MockClient((request) async {
          final uri = request.url;
          if (uri.path.endsWith('/rpc/get_featured')) {
            return http.Response(
                jsonEncode(<Map<String, dynamic>>[
                  <String, dynamic>{
                    'product_id': 'p1',
                    'name_ar': 'Latte',
                    'name_en': 'Latte',
                    'image_url': 'https://img.test/p1.png',
                    'effective_price': 100,
                    'regular_price': 100,
                    'discount_percentage': 0,
                    'source': 'manual',
                  },
                ]),
                200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('[]', 200,
              request: request, headers: {'content-type': 'application/json'});
        }),
      ),
    );

    final featured = await repository.getFeatured(branchId: branch);
    expect(featured.first.hasDiscount, isFalse);
  });
}
