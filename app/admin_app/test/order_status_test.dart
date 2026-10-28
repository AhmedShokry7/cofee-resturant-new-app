import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/core/models/order_status_codes.dart';
import 'package:admin_app/core/models/order_status.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filtering.dart';

void main() {
  setUp(() {
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  tearDown(() {
    AppLocale.instance.debugSet(AppLanguage.english);
  });

  group('order status mapping', () {
    test('every stored status of the database has a label and a colour', () {
      for (final code in const [
        'pending',
        'confirmed',
        'preparing',
        'ready',
        'out_for_delivery',
        'completed',
        'cancelled',
      ]) {
        final view = OrderStatusView.of(code);
        expect(view.code, code);
        expect(view.label, S.orderStatusLabel(code));
        expect(
          view.label,
          isNot(code),
          reason: 'status $code must be translated',
        );
      }
    });

    test('the label follows the language of the panel', () {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      expect(OrderStatusView.of('pending').label, S.statusPending);
      expect(OrderStatusView.of('pending').label, isNot('Pending'));

      AppLocale.instance.debugSet(AppLanguage.english);
      expect(OrderStatusView.of('pending').label, 'Pending');
    });

    test('an unsuccessful order never gets the success colour', () {
      final completed = OrderStatusView.of('completed').color;
      final cancelled = OrderStatusView.of('cancelled').color;
      final failed = OrderPaymentStatusView.of('failed').color;
      expect(cancelled, isNot(completed));
      expect(failed, isNot(completed));
    });

    test('an unknown status keeps a neutral fallback', () {
      final view = OrderStatusView.of('brand_new_status');
      expect(view.code, 'brand_new_status');
      expect(view.label, S.unknownOrderStatus);
    });

    test('only completed and cancelled end an order', () {
      expect(OrderStatusView.of('completed').isTerminal, isTrue);
      expect(OrderStatusView.of('cancelled').isTerminal, isTrue);
      expect(OrderStatusView.of('pending').isTerminal, isFalse);
      expect(OrderStatusView.of('preparing').isTerminal, isFalse);
    });
  });

  group('the one status vocabulary', () {
    final orders = <AdminOrder>[
      for (final code in OrderStatusCodes.all)
        AdminOrder(
          id: 'o',
          orderNumber: '1001',
          fulfillmentType: 'pickup',
          status: code,
          paymentStatus: 'paid',
          subtotal: 20,
          discountTotal: 0,
          deliveryFee: 0,
          taxTotal: 0,
          grandTotal: 20,
        ),
    ];

    test('the codes are exactly the statuses the column holds', () {
      expect(OrderStatusCodes.all, const <String>[
        'pending',
        'confirmed',
        'preparing',
        'ready',
        'out_for_delivery',
        'completed',
        'cancelled',
      ]);
    });

    test('the tabs partition the directory without losing a row', () {
      expect(
        filterOrders(orders, status: 'processing').map((o) => o.status).toSet(),
        OrderStatusCodes.processing,
      );
      expect(
        filterOrders(orders, status: 'shipped').map((o) => o.status),
        const <String>[OrderStatusCodes.outForDelivery],
      );

      const buckets = <String>[
        'processing',
        'shipped',
        'completed',
        'cancelled',
      ];
      final counted = buckets.fold<int>(
        0,
        (sum, code) => sum + filterOrders(orders, status: code).length,
      );
      expect(counted, filterOrders(orders, status: '').length);
    });

    test('a closed order is never counted as work the branch still holds', () {
      for (final code in OrderStatusCodes.closed) {
        expect(OrderStatusCodes.processing.contains(code), isFalse);
        expect(OrderStatusView.of(code).isTerminal, isTrue);
      }
    });
  });

  group('payment status mapping', () {
    test('every payment status of the database has a label', () {
      for (final code in const [
        'unpaid',
        'pending',
        'paid',
        'failed',
        'refunded',
      ]) {
        final view = OrderPaymentStatusView.of(code);
        expect(view.label, S.paymentStatusLabel(code));
        expect(
          view.label,
          isNot(code),
          reason: 'status $code must be translated',
        );
      }
    });

    test('paid and failed never share a colour', () {
      expect(
        OrderPaymentStatusView.of('paid').color,
        isNot(OrderPaymentStatusView.of('failed').color),
      );
    });
  });

  group('fulfillment mapping', () {
    test('delivery and pickup are localized', () {
      expect(OrderFulfillmentView.of('delivery').label, S.fulfillmentDelivery);
      expect(OrderFulfillmentView.of('pickup').label, S.fulfillmentPickup);
      expect(OrderFulfillmentView.of('delivery').isDelivery, isTrue);
      expect(OrderFulfillmentView.of('pickup').isDelivery, isFalse);
    });

    test('every type the database allows has a label', () {
      // `ck_orders_fulfillment_type` يقبل هذه الأنواع الثلاثة، وكل طلب نقطة بيع
      // هو `dine_in`.
      for (final code in <String>['delivery', 'pickup', 'dine_in']) {
        expect(
          OrderFulfillmentView.of(code).label,
          isNot(S.unknownFulfillment),
          reason: code,
        );
      }
      expect(OrderFulfillmentView.allCodes, <String>[
        'delivery',
        'pickup',
        'dine_in',
      ]);
    });
  });
}
