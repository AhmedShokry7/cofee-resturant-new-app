import 'dart:convert';

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

/// الورق يُرسم الآن في الذاكرة مباشرة، بلا متصفح وبلا وسيط HTML: يكفي أن
/// تُنتج المستندات ملف PDF يبدأ بترويسة PDF المعتادة.
void _expectPdfBytes(List<int> bytes) {
  expect(bytes, isNotEmpty);
  expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AppLocale.instance.debugSet(AppLanguage.arabic));

  group('statement data', () {
    test('every printed column keeps the values the panel shows', () {
      final rows = paymentStatementRows(const [
        _payment,
        AdminPayment(
          id: 'payment-2',
          provider: 'paymob',
          amount: 79.5,
          currencyCode: 'EGP',
          status: 'refunded',
        ),
      ]);

      expect(rows, hasLength(2));
      expect(rows.first, <String>[
        'ORD-1001',
        'أحمد <شكري>',
        'stripe',
        'ref_1',
        '${localizeDigits('120.50')} EGP',
        S.paymentStatusPaid,
        '-',
        'visa •••• 4242',
      ]);
      // بلا طلب ولا عميل ولا مرجع ولا بطاقة: شرطة لا فراغ، كي لا يقرأ الورق
      // صمتًا كأنه بيانات.
      expect(rows.last[0], '-');
      expect(rows.last[1], '-');
      expect(rows.last[2], 'paymob');
      expect(rows.last[3], '-');
      expect(rows.last[5], S.paymentStatusRefunded);
      expect(rows.last[7], '-');
    });

    test('headers name the eight columns in the printed order', () {
      expect(paymentStatementHeaders(), <String>[
        S.orderNumber,
        S.customer,
        S.provider,
        S.reference,
        S.amount,
        S.paymentStatusLabelTitle,
        S.paidAt,
        S.paymentCard,
      ]);
    });

    test('the collected total counts captured rows only', () {
      expect(
        paymentStatementCollected(const [
          _payment,
          AdminPayment(
            id: 'payment-2',
            provider: 'stripe',
            amount: 79.5,
            currencyCode: 'EGP',
            status: 'captured',
          ),
          AdminPayment(
            id: 'payment-3',
            provider: 'paymob',
            amount: 500,
            currencyCode: 'EGP',
            status: 'refunded',
          ),
        ]),
        '${localizeDigits('200.00')} EGP',
      );

      expect(
        paymentStatementCollected(const [
          AdminPayment(
            id: 'a',
            provider: 'stripe',
            amount: 10,
            currencyCode: 'SAR',
            status: 'captured',
          ),
          AdminPayment(
            id: 'b',
            provider: 'stripe',
            amount: 5,
            currencyCode: 'EGP',
            status: 'captured',
          ),
        ]),
        '${localizeDigits('10.00')} SAR • ${localizeDigits('5.00')} EGP',
      );
    });

    test('nothing captured prints no total instead of a zero', () {
      expect(
        paymentStatementCollected(const [
          AdminPayment(
            id: 'payment-1',
            provider: 'stripe',
            amount: 10,
            currencyCode: 'SAR',
            status: 'pending',
          ),
        ]),
        isNull,
      );
      expect(paymentStatementCollected(const []), isNull);
      expect(paymentStatementRows(const []), isEmpty);
    });
  });

  group('receipt data', () {
    test('fields carry the transaction, its card and its verification', () {
      final fields = Map.fromEntries(
        paymentReceiptFields(_payment)
            .map((entry) => MapEntry(entry.$1, entry.$2)),
      );

      expect(fields[S.orderNumber], 'ORD-1001');
      expect(fields[S.customer], 'أحمد <شكري>');
      expect(fields[S.provider], 'stripe');
      expect(fields[S.reference], 'ref_1');
      expect(fields[S.paymentStatusLabelTitle], S.paymentStatusPaid);
      expect(fields[S.paymentCard], 'visa •••• 4242');
      expect(fields[S.paymentCardHolder], 'أحمد <شكري>');
      expect(fields[S.verifiedByServer], S.yes);
      // النص يمر كما هو: لا وسيط لغة توصيف يُهرَّب عبره، فالورق يُرسم مباشرًا.
      expect(fields[S.customer], contains('<شكري>'));
    });

    test('a bare transaction answers with dashes and its own id', () {
      final fields = Map.fromEntries(
        paymentReceiptFields(
          const AdminPayment(
            id: 'payment-9',
            provider: 'paypal',
            amount: 12,
            currencyCode: 'SAR',
            status: 'failed',
          ),
        ).map((entry) => MapEntry(entry.$1, entry.$2)),
      );

      expect(fields[S.orderNumber], 'payment-9');
      expect(fields[S.customer], S.unknownCustomer);
      expect(fields[S.reference], '-');
      expect(fields[S.paymentCard], '-');
      expect(fields[S.paymentStatusLabelTitle], S.paymentStatusFailed);
      expect(fields[S.verifiedByServer], S.no);
      expect(fields[S.paidAt], '-');
      expect(fields[S.refundedAt], '-');
    });
  });

  group('pdf documents', () {
    test('the Arabic statement is drawn as a landscape PDF', () async {
      final document = await buildPaymentStatementDocument(const [_payment]);
      _expectPdfBytes(await document.save());
    });

    test('an empty statement still draws its headers', () async {
      final document = await buildPaymentStatementDocument(const []);
      _expectPdfBytes(await document.save());
    });

    test('the English receipt is drawn as a portrait PDF', () async {
      AppLocale.instance.debugSet(AppLanguage.english);

      final document = await buildPaymentReceiptDocument(_payment);
      _expectPdfBytes(await document.save());
    });

    test('many rows span more than one page', () async {
      final payments = List<AdminPayment>.generate(
        60,
        (index) => AdminPayment(
          id: 'payment-$index',
          orderNumber: 'ORD-$index',
          customerName: 'عميل $index',
          provider: 'stripe',
          amount: 10.0 + index,
          currencyCode: 'SAR',
          status: 'captured',
          paidAt: DateTime.utc(2026, 10, 31),
        ),
      );

      final document = await buildPaymentStatementDocument(payments);
      _expectPdfBytes(await document.save());
      expect(paymentStatementCollected(payments), isNotNull);
    });
  });

  test('filters payments by localized status, reference and card', () {
    final captured = PaymentStatusView.of('captured').label;
    expect(filterPayments([_payment], captured), [_payment]);
    expect(filterPayments([_payment], '4242'), [_payment]);
    expect(filterPayments([_payment], 'ref_1'), [_payment]);
    expect(filterPayments([_payment], 'paymob'), isEmpty);
  });
}
