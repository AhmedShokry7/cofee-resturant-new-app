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

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.arabic));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.arabic));

  test('the Arabic invoice is RTL, escaped and totals the sale', () {
    final receipt = _receipt();
    final document = buildPosReceiptDocument(receipt);

    expect(receipt.itemCount, 3);
    expect(receipt.orderNote, 'تغليف هدية & <بطاقة>');

    expect(document, contains('dir="rtl" lang="ar"'));
    expect(document, contains(S.posTaxInvoiceTitle));
    expect(document, contains(S.posTaxInvoiceTitleAlt));
    expect(document, contains(S.posReceiptDocumentTitle));
    expect(document, contains('POS-2026-000042'));
    expect(document, contains(S.posInvoiceNumber));
    expect(document, contains(S.posInvoiceDateTime));
    expect(document, contains(S.posTable));
    expect(document, contains(S.posCustomer));
    expect(document, contains('أحمد محمد'));
    expect(document, contains('01000000000'));
    expect(document, isNot(contains(S.posKitchenReceiptNote)));
    expect(document, isNot(contains(S.posDineIn)));
    expect(document, contains(S.posReceiptPaymentMethod));
    expect(document, contains('نقدي'));
    expect(document, contains(S.posQuantity));
    expect(document, contains(S.posItems));
    expect(document, contains(S.posBeforeDiscount));
    expect(document, contains(S.posDiscount));
    expect(document, contains(S.posAfterDiscount));
    expect(document, contains(S.posTaxableAmount));
    expect(document, contains(S.posVatRate));
    expect(document, contains(S.posVatAmount));
    expect(document, contains(S.posTotal));
    expect(document, contains(S.posOrderNote));
    expect(document, contains(S.posReceiptThanks));
    expect(document, contains(S.posTaxInvoiceCompliance));
    expect(document, contains('size: A4 portrait'));

    expect(document, contains('لاتيه'));
    expect(document, contains('كيك'));
    expect(document, contains('كبير'));
    expect(document, contains('>٢<'));

    expect(document, contains('بدون &lt;سكر&gt;'));
    expect(document, isNot(contains('بدون <سكر>')));
    expect(document, contains('تغليف هدية &amp; &lt;بطاقة&gt;'));
    expect(document, isNot(contains('تغليف هدية & <بطاقة>')));

    expect(document, contains(S.posSellerVatNumber));
    expect(document, contains('مقهى النخبة للتجارة'));
    expect(document, contains('الرياض - حي العليا'));
    expect(document, contains('0112345678'));
    expect(document, contains(localizeDigits('310123456789003')));

    expect(document, contains(localizeDigits('85.00')));
    expect(document, contains(localizeDigits('20.00')));
    expect(document, contains(localizeDigits('65.00')));
    expect(document, contains(localizeDigits('9.75')));
    expect(document, contains(localizeDigits('74.75')));
    expect(document, contains('SAR'));

    expect(document, contains(S.posInvoiceQrCaption));
    expect(document, contains('<svg'));
    expect(document, isNot(contains(S.posVatNumberMissing)));
  });

  test('the English invoice follows the English layout', () {
    AppLocale.instance.debugSet(AppLanguage.english);

    final document = buildPosReceiptDocument(_receipt());

    expect(document, contains('dir="ltr" lang="en"'));
    expect(document, contains(S.posTaxInvoiceTitle));
    expect(document, contains(S.posTaxInvoiceTitleAlt));
    expect(document, contains(S.posTable));
    expect(document, contains(S.posCustomer));
    expect(document, contains('أحمد محمد'));
    expect(document, isNot(contains(S.posKitchenReceiptNote)));
    expect(document, contains(S.posReceiptThanks));
    expect(document, contains('Cash'));
    expect(document, contains('Latte'));
    expect(document, contains('Cake'));
    expect(document, contains('Large'));
    expect(document, contains('85.00'));
    expect(document, contains('20.00'));
    expect(document, contains('65.00'));
    expect(document, contains('9.75'));
    expect(document, contains('74.75'));
    expect(document, contains('SAR'));
    expect(document, contains('310123456789003'));
    expect(document, contains('مقهى النخبة للتجارة'));
    expect(document, contains('Riyadh - Olaya'));
    expect(document, contains(S.posInvoiceQrCaption));
    expect(document, contains('<svg'));
    expect(document, isNot(contains('>٢<')));
  });

  test('a sale without the branch tax identity warns instead of a QR', () {
    AppLocale.instance.debugSet(AppLanguage.english);

    final receipt = _receiptWithoutSeller();
    final document = buildPosReceiptDocument(receipt);

    expect(receipt.itemCount, 0);
    expect(buildPosReceiptQrData(receipt), isNull);
    expect(document, contains('dir="ltr" lang="en"'));
    expect(document, contains(S.posTable));
    expect(document, contains('>-<'));
    expect(document, isNot(contains(S.posDineIn)));
    expect(document, isNot(contains(S.posPickup)));
    expect(document, contains(S.posTaxableAmount));
    expect(document, contains(S.posVatAmount));
    expect(document, contains('0.00 EGP'));
    expect(document, contains('20.00 EGP'));
    expect(document, contains('نقدي'));
    expect(document, contains(S.posInvoiceDateTime));
    expect(document, contains(S.posReceiptThanks));
    expect(document, contains(S.posVatNumberMissing));
    expect(document, isNot(contains('<svg')));
    expect(document, isNot(contains(S.posOrderNote)));
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

  test('special characters in the order number are escaped', () {
    AppLocale.instance.debugSet(AppLanguage.english);

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
    final document = buildPosReceiptDocument(receipt);

    expect(document, contains('POS-&lt;42&gt;&amp;&quot;'));
    expect(document, isNot(contains('POS-<42>&"')));
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
    final document = buildPosReceiptDocument(receipt);

    expect(receipt.result.isSplitPayment, isTrue);
    expect(document, contains(S.posPayCash));
    expect(document, contains(S.posPayCard));
    expect(document, contains('10.00 SAR'));
    expect(document, contains('36.00 SAR'));
    expect(document, isNot(contains(S.posReceiptPaymentMethod)));
  });
}
