import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';

void main() {
  test('operational statuses map to the three customer buckets', () {
    expect(OrderStatus.fromDatabase('pending'), OrderStatus.active);
    expect(OrderStatus.fromDatabase('confirmed'), OrderStatus.active);
    expect(OrderStatus.fromDatabase('preparing'), OrderStatus.active);
    expect(OrderStatus.fromDatabase('ready'), OrderStatus.active);
    expect(OrderStatus.fromDatabase('out_for_delivery'), OrderStatus.active);
    expect(OrderStatus.fromDatabase('completed'), OrderStatus.completed);
    expect(OrderStatus.fromDatabase('cancelled'), OrderStatus.cancelled);
    expect(() => OrderStatus.fromDatabase('refunded'), throwsFormatException);
  });

  test('invoice lines keep their frozen price when the catalogue moves', () {
    final line = OrderItemModel.fromDatabase(
      order: {
        'id': 'order-1',
        'order_number': '1007',
        'status': 'completed',
        'placed_at': '2026-10-01T10:00:00Z',
      },
      item: {
        'id': 'line-1',
        'product_id': 'product-1',
        'product_name_ar': 'لاتيه',
        'product_name_en': 'Latte',
        'sku_snapshot': 'LATTE',
        'image_snapshot': 'assets/images/product.png',
        'unit_price': 35,
        'quantity': 2,
        'line_total': 70,
        'note': 'Large',
        'created_at': '2026-10-01T10:00:00Z',
      },
    );

    // The catalogue row may now cost something else. History must not follow it.
    final currentCatalogueRow = ProductModel(
      id: 'product-1',
      nameEn: 'Latte',
      nameAr: 'لاتيه',
      price: 999,
      image: AppImages.product,
    );

    expect(line.chargedUnit, 35);
    expect(line.chargedTotal, 70);
    expect(line.displayNumber, '1007');
    expect(currentCatalogueRow.price, 999);
  });

  test('a deleted product still renders as an invoice line', () {
    final line = OrderItemModel.fromDatabase(
      order: {
        'id': 'order-2',
        'order_number': '1008',
        'status': 'cancelled',
        'placed_at': '2026-10-02T10:00:00Z',
      },
      item: {
        'id': 'line-2',
        'product_id': null,
        'product_name_ar': '',
        'product_name_en': '',
        'sku_snapshot': 'OLD',
        'image_snapshot': null,
        'unit_price': 20,
        'quantity': 1,
        'line_total': 20,
        'note': '',
        'created_at': '2026-10-02T10:00:00Z',
      },
    );

    expect(line.product.id, contains('removed-product'));
    expect(line.product.name, 'Removed product');
    expect(line.product.image, AppImages.product);
    expect(line.status, OrderStatus.cancelled);
  });
}
