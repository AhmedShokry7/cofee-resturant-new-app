import 'package:flutter_test/flutter_test.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';

/// Cover for the per-line coupon discount now carried on the invoice.
///
/// 072 added `discount_total` to `orders.order_items`. Before this change
/// `OrderItemModel.fromDatabase` read `discount_total` only from the order
/// *header*, so every line in an order showed the same (whole-order) discount
/// — or none at all — and the per-line breakdown the server computed was
/// invisible on the receipt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  Map<String, dynamic> orderRow({double? discountTotal}) => {
    'id': 'order-1',
    'order_number': 'ORD-1',
    'status': 'completed',
    'fulfillment_type': 'pickup',
    'currency_code': 'SAR',
    'placed_at': '2026-10-01T10:00:00Z',
    'subtotal': 50.0,
    'discount_total': discountTotal,
  };

  Map<String, dynamic> itemRow({
    required String id,
    required String productId,
    double unitPrice = 10,
    int quantity = 1,
    double? lineDiscount,
  }) => {
    'id': id,
    'product_id': productId,
    'product_name_en': productId,
    'unit_price': unitPrice,
    'quantity': quantity,
    'line_total': unitPrice * quantity,
    'discount_total': lineDiscount,
    'created_at': '2026-10-01T10:00:00Z',
  };

  test('a line carries its own discount, not the header total', () {
    final item = OrderItemModel.fromDatabase(
      order: orderRow(discountTotal: 100),
      item: itemRow(
        id: 'line-1',
        productId: 'p1',
        unitPrice: 12,
        quantity: 1,
        lineDiscount: 2.4,
      ),
    );

    // The header total is 100; the line's own share is 2.4. Before the fix
    // the line showed 100, which made every line look fully discounted.
    expect(item.discountTotal, 100);
    expect(item.lineDiscountTotal, 2.4);
  });

  test('a line with no discount has null, not zero', () {
    final item = OrderItemModel.fromDatabase(
      order: orderRow(),
      item: itemRow(id: 'line-2', productId: 'p2', unitPrice: 5, quantity: 1),
    );
    expect(item.lineDiscountTotal, isNull);
  });

  test('the charged total is unchanged by a discount', () {
    final item = OrderItemModel.fromDatabase(
      order: orderRow(),
      item: itemRow(
        id: 'line-3',
        productId: 'p3',
        unitPrice: 12,
        quantity: 2,
        lineDiscount: 2.4,
      ),
    );
    expect(item.chargedTotal, 24);
  });

  test('an absent discount column does not throw', () {
    final row = itemRow(id: 'line-4', productId: 'p4', unitPrice: 8);
    row.remove('discount_total');
    final item = OrderItemModel.fromDatabase(order: orderRow(), item: row);
    expect(item.lineDiscountTotal, isNull);
  });

  test('two lines in one order keep their own shares', () {
    final order = orderRow(discountTotal: 6);
    final a = OrderItemModel.fromDatabase(
      order: order,
      item: itemRow(
        id: 'line-a',
        productId: 'p1',
        unitPrice: 12,
        quantity: 1,
        lineDiscount: 2.4,
      ),
    );
    final b = OrderItemModel.fromDatabase(
      order: order,
      item: itemRow(
        id: 'line-b',
        productId: 'p2',
        unitPrice: 5,
        quantity: 1,
        lineDiscount: 0,
      ),
    );

    expect(a.lineDiscountTotal, 2.4);
    expect(b.lineDiscountTotal, 0);
    // The header total is the same for both lines, as it should be.
    expect(a.discountTotal, 6);
    expect(b.discountTotal, 6);
  });
}
