import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/presentation/models/order_status.dart';

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
      expect(view.label, 'brand_new_status');
    });

    test('only completed and cancelled end an order', () {
      expect(OrderStatusView.of('completed').isTerminal, isTrue);
      expect(OrderStatusView.of('cancelled').isTerminal, isTrue);
      expect(OrderStatusView.of('pending').isTerminal, isFalse);
      expect(OrderStatusView.of('preparing').isTerminal, isFalse);
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
  });
}
