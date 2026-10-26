import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/models/order_edit_rules.dart';

AdminOrder _order({
  String status = 'pending',
  String paymentStatus = 'unpaid',
}) {
  return AdminOrder(
    id: 'o1',
    orderNumber: '1001',
    fulfillmentType: 'delivery',
    status: status,
    paymentStatus: paymentStatus,
    subtotal: 10,
    discountTotal: 0,
    deliveryFee: 0,
    taxTotal: 0,
    grandTotal: 10,
  );
}

void main() {
  group('OrderEditRules.canEditItems', () {
    test('a pending order may be edited', () {
      expect(OrderEditRules.canEditItems(_order()), isTrue);
    });

    test('a completed order may not be edited', () {
      expect(OrderEditRules.canEditItems(_order(status: 'completed')), isFalse);
    });

    test('a cancelled order may not be edited', () {
      expect(OrderEditRules.canEditItems(_order(status: 'cancelled')), isFalse);
    });

    test('a refunded order may not be edited', () {
      expect(
        OrderEditRules.canEditItems(_order(paymentStatus: 'refunded')),
        isFalse,
      );
    });
  });

  group('OrderEditRules.canRemoveItem', () {
    test('needs an editable order and the identifier of the item', () {
      expect(OrderEditRules.canRemoveItem(_order(), hasItemId: true), isTrue);
      expect(OrderEditRules.canRemoveItem(_order(), hasItemId: false), isFalse);
      expect(
        OrderEditRules.canRemoveItem(
          _order(status: 'completed'),
          hasItemId: true,
        ),
        isFalse,
      );
    });
  });
}
