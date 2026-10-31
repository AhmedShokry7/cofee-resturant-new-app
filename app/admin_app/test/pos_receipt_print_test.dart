import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/pos/domain/entities/pos_cart.dart';
import 'package:admin_app/features/pos/domain/entities/pos_catalog.dart';
import 'package:admin_app/features/pos/domain/entities/pos_order_result.dart';
import 'package:admin_app/features/pos/domain/entities/pos_receipt.dart';
import 'package:admin_app/features/pos/data/pos_receipt_print_service.dart';

const _latte = PosProduct(
  id: 'p-latte',
  nameAr: 'لاتيه',
  nameEn: 'Latte',
  unitPrice: 20,
);
const _cake = PosProduct(
  id: 'p-cake',
  nameAr: 'كيك',
  nameEn: 'Cake',
  unitPrice: 15,
);
const _large = PosOptionValue(
  id: 'v-large',
  nameAr: 'كبير',
  nameEn: 'Large',
  priceDelta: 5,
);

PosReceipt _receipt() {
  return PosReceipt(
    result: PosOrderResult(
      orderId: 'o1',
      orderNumber: 'POS-2026-000042',
      subtotal: 65,
      taxTotal: 9.75,
      grandTotal: 74.75,
      currencyCode: 'SAR',
      fulfillmentType: PosFulfillmentType.dineIn,
      tableNumber: ' 7 ',
      paymentMethodId: 'pay-cash',
      paymentMethodCode: 'cash',
      paymentMethodNameAr: 'نقدي',
      paymentMethodNameEn: 'Cash',
      customerId: 'c1',
      customerName: 'أحمد محمد',
      customerPhone: '01000000000',
      customerSource: 'walk_in',
      placedAt: DateTime.utc(2026, 10, 26, 10, 15),
      productDiscountTotal: 20,
      beforeDiscountTotal: 85,
      taxRate: 15,
      taxIncluded: true,
      sellerNameAr: 'مقهى النخبة',
      sellerNameEn: 'Elite Cafe',
      sellerLegalName: 'مقهى النخبة للتجارة',
      sellerVatNumber: '310123456789003',
      sellerAddressAr: 'الرياض - حي العليا',
      sellerAddressEn: 'Riyadh - Olaya',
      sellerPhone: '0112345678',
    ),
    lines: [
      PosCartLine(
        product: _latte,
        options: const [_large],
        quantity: 2,
        note: 'بدون <سكر>',
      ),
      PosCartLine(product: _cake),
    ],
    note: 'تغليف هدية & <بطاقة>',
  );
}

PosReceipt _receiptWithoutSeller() {
  return const PosReceipt(
    result: PosOrderResult(
      orderId: 'o2',
      orderNumber: 'POS-2026-000043',
      subtotal: 20,
      grandTotal: 20,
      currencyCode: 'EGP',
      paymentMethodNameAr: 'نقدي',
    ),
  );
}

Map<int, String> _decodeTlv(String data) {
  final bytes = base64Decode(data);
  final fields = <int, String>{};
  var index = 0;
  while (index < bytes.length) {
    final tag = bytes[index++];
    final length = bytes[index++];
    fields[tag] = utf8.decode(bytes.sublist(index, index + length));
    index += length;
  }
  return fields;
}

Map<String, String> _asMap(List<(String, String)> fields) => {
  for (final field in fields) field.$1: field.$2,
};

Map<String, String> _totalsMap(PosReceipt receipt) => {
  for (final (label, value, _) in posReceiptTotals(receipt)) label: value,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AppLocale.instance.debugSet(AppLanguage.arabic));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.arabic));

  group('arabic invoice', () {
    test('the seller block carries the tax identity', () {
      final lines = posReceiptSellerLines(_receipt());

      expect(lines.first, 'مقهى النخبة للتجارة');
      expect(lines, contains('الرياض - حي العليا'));
      expect(
        lines,
        contains(
          '${S.posSellerVatNumber}: ${localizeDigits('310123456789003')}',
        ),
      );
      expect(lines, contains('0112345678'));
      // الاسم النظامي يحل محل الاسم التجاري، فلا تكرار في الرأس ولا سطر فارغ.
      expect(lines, isNot(contains('مقهى النخبة')));
      expect(lines.every((line) => line.trim().isNotEmpty), isTrue);
    });

    test('the fields name the sale without leaking internal labels', () {
      final details = _asMap(posReceiptDetails(_receipt()));

      expect(details[S.posInvoiceNumber], 'POS-2026-000042');
      expect(details[S.posTable], '7');
      expect(details[S.posCustomer], 'أحمد محمد');
      expect(details[S.posCustomerPhone], '01000000000');
      expect(details[S.posReceiptPaymentMethod], 'نقدي');
      expect(details.containsKey(S.posInvoiceDateTime), isTrue);
      // الفاتورة الضريبية لا تذكر طريقة التقديم ولا ملاحظة المطبخ.
      expect(details.containsKey(S.posKitchenReceiptNote), isFalse);
      expect(details.containsKey(S.posDineIn), isFalse);
    });

    test('the item rows keep quantity, options and the line note', () {
      final lines = posReceiptPrintLines(_receipt());

      expect(lines, hasLength(2));
      expect(_receipt().itemCount, 3);
      expect(lines.first.quantity, localizeDigits('2'));
      expect(lines.first.name, 'لاتيه');
      expect(lines.first.details, contains('كبير'));
      expect(lines.first.details, contains('بدون <سكر>'));
      expect(lines.first.unitPrice, '${localizeDigits('25.00')} SAR');
      expect(lines.first.lineTotal, '${localizeDigits('50.00')} SAR');
      expect(lines.last.name, 'كيك');
      expect(lines.last.details, isEmpty);
    });

    test('the totals run from before the discount to the grand total', () {
      final totals = _totalsMap(_receipt());

      expect(totals[S.posBeforeDiscount], '${localizeDigits('85.00')} SAR');
      expect(totals[S.posDiscount], '- ${localizeDigits('20.00')} SAR');
      expect(totals[S.posAfterDiscount], '${localizeDigits('65.00')} SAR');
      expect(totals[S.posTaxableAmount], '${localizeDigits('65.00')} SAR');
      expect(totals[S.posVatRate], isNotNull);
      expect(totals[S.posVatAmount], '${localizeDigits('9.75')} SAR');
      expect(totals[S.posTotal], '${localizeDigits('74.75')} SAR');
      expect(
        posReceiptTotals(_receipt()).last.$3,
        isTrue,
        reason: 'الإجمالي آخر السطور وهو البارز',
      );
    });

    test('the QR is present whenever the tax identity is complete', () {
      expect(buildPosReceiptQrData(_receipt()), isNotNull);
    });
  });

  group('english invoice', () {
    setUp(() => AppLocale.instance.debugSet(AppLanguage.english));

    test('the same sale reads in English with Arabic names kept', () {
      final details = _asMap(posReceiptDetails(_receipt()));
      final lines = posReceiptPrintLines(_receipt());

      expect(details[S.posInvoiceNumber], 'POS-2026-000042');
      expect(details[S.posCustomer], 'أحمد محمد');
      expect(details[S.posReceiptPaymentMethod], 'Cash');
      expect(lines.first.name, 'Latte');
      expect(lines.first.details, contains('Large'));
      expect(lines.first.quantity, '2');
      expect(posReceiptSellerLines(_receipt()).first, 'مقهى النخبة للتجارة');
      expect(posReceiptSellerLines(_receipt()), contains('Riyadh - Olaya'));
      expect(_totalsMap(_receipt())[S.posTotal], '74.75 SAR');
    });
  });

  group('a sale without the branch tax identity', () {
    test('has no QR payload and no seller block beyond the name', () {
      final receipt = _receiptWithoutSeller();

      expect(buildPosReceiptQrData(receipt), isNull);
      expect(receipt.itemCount, 0);
      expect(posReceiptPrintLines(receipt), isEmpty);
      expect(posReceiptSellerLines(receipt), isEmpty);
      expect(receipt.orderNote.trim(), isEmpty);
    });

    test('keeps the table dash and the zero totals in the currency', () {
      final receipt = _receiptWithoutSeller();
      final details = _asMap(posReceiptDetails(receipt));
      final totals = _totalsMap(receipt);

      expect(details[S.posTable], '-');
      expect(details.containsKey(S.posDineIn), isFalse);
      expect(details.containsKey(S.posPickup), isFalse);
      expect(totals[S.posTaxableAmount], '${localizeDigits('20.00')} EGP');
      expect(totals[S.posVatAmount], '${localizeDigits('0.00')} EGP');
      expect(totals[S.posTotal], '${localizeDigits('20.00')} EGP');
      expect(totals.containsKey(S.posVatRate), isFalse);
      expect(details[S.posReceiptPaymentMethod], 'نقدي');
      expect(details.containsKey(S.posInvoiceDateTime), isTrue);
    });
  });

  group('the paper itself', () {
    test('builds a real PDF in Arabic and in English', () async {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      final arabicBytes = await (await buildPosReceiptDocument(_receipt()))
          .save();
      expect(arabicBytes, isNotEmpty);

      AppLocale.instance.debugSet(AppLanguage.english);
      final englishBytes = await (await buildPosReceiptDocument(_receipt()))
          .save();
      expect(
        latin1.decode(englishBytes.take(5).toList()),
        '%PDF-',
        reason: 'الفاتورة تُرسم PDFًا حقيقيًا لا صفحة وسيطة',
      );
    });

    test(
      'draws the missing-VAT warning instead of a QR without crashing',
      () async {
        final bytes = await (await buildPosReceiptDocument(
          _receiptWithoutSeller(),
        )).save();
        expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
      },
    );

    test('keeps the order text verbatim on the paper', () {
      const receipt = PosReceipt(
        result: PosOrderResult(
          orderId: 'o3',
          orderNumber: 'POS-<42>&"',
          subtotal: 10,
          grandTotal: 10,
          currencyCode: 'SAR',
          paymentMethodNameEn: 'Cash',
        ),
      );

      // لا وسيط HTML: الورقة تحمل النص نفسه الذي في القاعدة، بلا تحويل رموز.
      expect(
        _asMap(posReceiptDetails(receipt))[S.posInvoiceNumber],
        'POS-<42>&"',
      );
    });

    test('a split sale prints one payment row per tender', () {
      AppLocale.instance.debugSet(AppLanguage.english);

      const receipt = PosReceipt(
        result: PosOrderResult(
          orderId: 'o4',
          orderNumber: 'POS-2026-000044',
          subtotal: 40,
          taxTotal: 6,
          grandTotal: 46,
          currencyCode: 'SAR',
          paymentMethodId: 'pay-card',
          paymentMethodCode: 'card',
          paymentMethodNameAr: 'بطاقة',
          paymentMethodNameEn: 'Card',
          payments: [
            PosTender(
              methodId: 'pay-cash',
              code: 'cash',
              nameAr: 'نقدي',
              nameEn: 'Cash',
              amount: 10,
            ),
            PosTender(
              methodId: 'pay-card',
              code: 'card',
              nameAr: 'بطاقة',
              nameEn: 'Card',
              amount: 36,
            ),
          ],
        ),
      );

      final details = posReceiptDetails(receipt);
      expect(receipt.result.isSplitPayment, isTrue);
      expect(
        details.any((field) => field.$1 == S.posReceiptPaymentMethod),
        isFalse,
      );
      expect(_asMap(details)[S.posPayCash], '10.00 SAR');
      expect(_asMap(details)[S.posPayCard], '36.00 SAR');
    });
  });

  test('the QR carries the five ZATCA TLV tags', () {
    final receipt = _receipt();
    final data = buildPosReceiptQrData(receipt);

    expect(data, isNotNull);
    final fields = _decodeTlv(data!);
    expect(fields[1], 'مقهى النخبة للتجارة');
    expect(fields[2], '310123456789003');
    expect(fields[3], '2026-10-26T10:15:00Z');
    expect(fields[4], '74.75');
    expect(fields[5], '9.75');
    expect(
      posInvoiceTimestamp(DateTime.utc(2026, 1, 2, 3, 4, 5)),
      '2026-01-02T03:04:05Z',
    );
  });
}
