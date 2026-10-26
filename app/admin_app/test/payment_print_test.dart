import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/payments/data/models/admin_payment.dart';
import 'package:admin_app/features/payments/data/payment_print_service.dart';
import 'package:admin_app/features/payments/presentation/models/payment_status.dart';
import 'package:admin_app/features/payments/presentation/widgets/payment_records.dart';

const _payment = AdminPayment(
  id: 'payment-1',
  orderNumber: 'ORD-1001',
  customerName: 'أحمد <شكري>',
  provider: 'stripe',
  providerReference: 'ref_1',
  amount: 120.5,
  currencyCode: 'EGP',
  status: 'captured',
  cardBrand: 'visa',
  cardLast4: '4242',
  cardHolderName: 'أحمد <شكري>',
  verifiedByServer: true,
);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.arabic));

  test(
    'print statement escapes customer text and totals captured payments',
    () {
      final document = buildPaymentPrintDocument([
        _payment,
        const AdminPayment(
          id: 'payment-2',
          provider: 'stripe',
          amount: 79.5,
          currencyCode: 'EGP',
          status: 'captured',
        ),
        const AdminPayment(
          id: 'payment-3',
          provider: 'paymob',
          amount: 500,
          currencyCode: 'EGP',
          status: 'refunded',
        ),
      ]);

      expect(document, contains('dir="rtl"'));
      expect(document, contains('أحمد &lt;شكري&gt;'));
      expect(document, isNot(contains('أحمد <شكري>')));
      expect(document, contains('ORD-1001'));
      expect(document, contains(S.paymentStatusPaid));
      expect(document, contains(S.paymentStatusRefunded));
      expect(document, contains(localizeDigits('200.00')));
      expect(document, isNot(contains(localizeDigits('700.00'))));
      expect(document, contains(S.paymentsPrintCount(3)));
    },
  );

  test('print statement follows the English layout when selected', () {
    AppLocale.instance.debugSet(AppLanguage.english);

    final document = buildPaymentPrintDocument(const [
      AdminPayment(
        id: 'payment-1',
        provider: 'stripe',
        amount: 10,
        currencyCode: 'SAR',
        status: 'pending',
      ),
    ]);

    expect(document, contains('dir="ltr"'));
    expect(document, contains(S.paymentStatusPending));
    expect(document, contains(S.paymentsPrintTitle));
  });

  test('single receipt carries the transaction details and escapes text', () {
    final document = buildPaymentReceiptDocument(_payment);

    expect(document, contains('dir="rtl"'));
    expect(document, contains(S.paymentReceiptTitle));
    expect(document, contains('payment-1'));
    expect(document, contains('ORD-1001'));
    expect(document, contains('أحمد &lt;شكري&gt;'));
    expect(document, contains(S.paymentStatusPaid));
    expect(document, contains(localizeDigits('120.50')));
    expect(document, contains('EGP'));
    expect(document, contains('visa •••• 4242'));
    expect(document, contains(S.yes));
    expect(document, contains('size: A4 portrait'));
  });

  test('filters payments by localized status, reference and card', () {
    final captured = PaymentStatusView.of('captured').label;
    expect(filterPayments([_payment], captured), [_payment]);
    expect(filterPayments([_payment], '4242'), [_payment]);
    expect(filterPayments([_payment], 'ref_1'), [_payment]);
    expect(filterPayments([_payment], 'paymob'), isEmpty);
  });
}
