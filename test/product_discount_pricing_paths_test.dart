import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:new_coffee/features/menu/data/repositories/supabase_product_repository.dart';

void main() {
  const branch = '00000000-0000-4000-8000-000000000101';

  Future<http.Response> handle(http.BaseRequest request) async {
    final uri = request.url;
    if (uri.path.endsWith('/products')) {
      return http.Response(
        jsonEncode(<Map<String, dynamic>>[
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
            'compare_at_price': null,
            'image_url': 'https://img.test/p1.png',
            'is_featured': false,
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
          },
        ]),
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
    return http.Response(
      '[]',
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }

  test('branch discount overrides general discount in catalog', () async {
    final repository = SupabaseProductRepository(
      SupabaseClient(
        'https://catalog.test',
        'anon-key',
        httpClient: MockClient(handle),
      ),
    );
    final products = await repository.getProducts(branchId: branch);
    expect(products, hasLength(1));
    expect(products.first.price, closeTo(80, 0.001));
  });

  test('use_general_discount false disables inherited discount', () async {
    Future<http.Response> handle2(http.BaseRequest request) async {
      final uri = request.url;
      if (uri.path.endsWith('/products')) {
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
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
              'compare_at_price': null,
              'image_url': 'https://img.test/p1.png',
              'is_featured': false,
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
            },
          ]),
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
              'discount_percentage': null,
              'discount_starts_at': null,
              'discount_ends_at': null,
              'use_general_discount': false,
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

    final repository = SupabaseProductRepository(
      SupabaseClient(
        'https://catalog.test',
        'anon-key',
        httpClient: MockClient(handle2),
      ),
    );
    final products = await repository.getProducts(branchId: branch);
    expect(products.first.price, closeTo(100, 0.001));
  });
}
