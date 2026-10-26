import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/core/models/admin_product.dart';

void main() {
  test('admin product keeps discount fields', () {
    final product = AdminProduct(
      id: 'p1',
      nameAr: 'a',
      nameEn: 'b',
      sku: 's',
      slug: 'slug',
      basePrice: 100,
      discountPercentage: 10,
      discountStartsAt: DateTime(2026, 1, 1),
      discountEndsAt: DateTime(2026, 12, 31),
    );
    expect(product.discountPercentage, 10);
    expect(product.discountStartsAt, DateTime(2026, 1, 1));
    expect(product.discountEndsAt, DateTime(2026, 12, 31));
  });

  test('admin product parses discount fields from row', () {
    final product = AdminProduct.fromRow(<String, dynamic>{
      'id': 'p2',
      'name_ar': 'a',
      'name_en': 'b',
      'sku': 's',
      'slug': 'slug',
      'base_price': 100,
      'category_id': 'c1',
      'discount_percentage': 15,
      'discount_starts_at': '2026-01-01T00:00:00.000',
      'discount_ends_at': '2026-12-31T00:00:00.000',
    });
    expect(product.discountPercentage, 15);
    expect(product.discountStartsAt, isNotNull);
    expect(product.discountEndsAt, isNotNull);
  });
}
