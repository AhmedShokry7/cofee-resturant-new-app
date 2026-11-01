import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/features/menu/data/repositories/supabase_product_repository.dart';

void main() {
  const branch = '00000000-0000-4000-8000-000000000101';

  Map<String, dynamic> productJson() => <String, dynamic>{
    'id': 'p1',
    'category_id': 'c1',
    'sku': 'CF-1',
    'slug': 'latte',
    'name_ar': 'Latte',
    'name_en': 'Latte',
    'description_ar': '',
    'description_en': '',
    'base_price': 100,
    'compare_at_price': null,
    'image_url': 'https://img.test/p1.png',
    'is_featured': true,
    'prep_minutes': 3,
    'category_slug': 'hot-coffee',
    'category_name_ar': 'Coffee',
    'category_name_en': 'Hot Coffee',
    'related_product_ids': <String>[],
    'discount_percentage': 10,
    'discount_starts_at': DateTime.now()
        .subtract(const Duration(hours: 1))
        .toIso8601String(),
    'discount_ends_at': DateTime.now()
        .add(const Duration(hours: 1))
        .toIso8601String(),
  };

  Future<http.Response> handle(http.BaseRequest request) async {
    final uri = request.url;
    if (uri.path.endsWith('/products')) {
      return http.Response(
        jsonEncode(<Map<String, dynamic>>[productJson()]),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    }
    if (uri.path.endsWith('/product_images')) {
      return http.Response(
        '[]',
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
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
            'discount_starts_at': DateTime.now()
                .subtract(const Duration(hours: 1))
                .toIso8601String(),
            'discount_ends_at': DateTime.now()
                .add(const Duration(hours: 1))
                .toIso8601String(),
            'use_general_discount': true,
          },
        ]),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    }
    if (uri.path.endsWith('/rpc/catalog_products_by_ids')) {
      return http.Response(
        jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'product': productJson(),
            'images': <Map<String, dynamic>>[],
            'effective_price': 80,
          },
        ]),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    }
    if (uri.path.endsWith('/rpc/search_products')) {
      return http.Response(
        jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            ...productJson(),
            'effective_price': 80,
            'rank': 1,
            'total_count': 1,
          },
        ]),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    }
    if (uri.path.endsWith('/rpc/get_featured')) {
      return http.Response(
        jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'product_id': 'p1',
            'name_ar': 'Latte',
            'name_en': 'Latte',
            'image_url': 'https://img.test/p1.png',
            'effective_price': 80,
            'source': 'manual',
          },
        ]),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(
      '[]',
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }

  test('getByIds returns authoritative discounted price', () async {
    final repository = SupabaseProductRepository(
      SupabaseClient(
        'https://catalog.test',
        'anon-key',
        httpClient: MockClient(handle),
      ),
    );
    final products = await repository.getByIds(['p1'], branchId: branch);
    expect(products, hasLength(1));
    expect(products.first.price, closeTo(80, 0.001));
  });

  test('search results use authoritative discounted price', () async {
    final repository = SupabaseProductRepository(
      SupabaseClient(
        'https://catalog.test',
        'anon-key',
        httpClient: MockClient(handle),
      ),
    );
    final products = await repository.search('latte', branchId: branch);
    expect(products, hasLength(1));
    expect(products.first.price, closeTo(80, 0.001));
  });

  test('featured products use authoritative discounted price', () async {
    final repository = SupabaseProductRepository(
      SupabaseClient(
        'https://catalog.test',
        'anon-key',
        httpClient: MockClient(handle),
      ),
    );
    final featured = await repository.getFeatured(branchId: branch);
    expect(featured, hasLength(1));
    expect(featured.first.effectivePrice, closeTo(80, 0.001));
  });
}
