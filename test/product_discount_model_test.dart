import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';

void main() {
  test('product model keeps discount fields', () {
    final product = ProductModel(
      id: 'p1',
      price: 100,
      image: '',
      discountPercentage: 10,
      discountStartsAt: DateTime(2026, 1, 1),
      discountEndsAt: DateTime(2026, 12, 31),
    );
    expect(product.discountPercentage, 10);
    expect(product.discountStartsAt, DateTime(2026, 1, 1));
    expect(product.discountEndsAt, DateTime(2026, 12, 31));
  });

  test('product model parses discount fields from json', () {
    final product = ProductModel.fromJson(<String, dynamic>{
      'id': 'p2',
      'base_price': 100,
      'discount_percentage': 15,
      'discount_starts_at': '2026-01-01T00:00:00.000',
      'discount_ends_at': '2026-12-31T00:00:00.000',
    });
    expect(product.discountPercentage, 15);
    expect(product.discountStartsAt, isNotNull);
    expect(product.discountEndsAt, isNotNull);
  });
}
