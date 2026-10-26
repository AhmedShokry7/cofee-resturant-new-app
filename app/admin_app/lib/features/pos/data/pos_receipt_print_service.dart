import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/services/html_print_runner.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/pos/domain/entities/pos_receipt.dart';
import 'package:admin_app/features/pos/data/pos_invoice_qr.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_format.dart';

Future<bool> printPosReceipt(PosReceipt receipt) =>
    printHtmlDocument(buildPosReceiptDocument(receipt));

/// The ZATCA QR payload of [receipt], or null when the seller identity needed
/// by a simplified tax invoice is not configured.
String? buildPosReceiptQrData(PosReceipt receipt) {
  final result = receipt.result;
  final sellerName = result.sellerLegalNameFor(AppLanguage.arabic).trim();
  final vatNumber = result.sellerVatNumber.trim();
  if (sellerName.isEmpty || vatNumber.isEmpty) return null;
  return buildPosInvoiceQrData(
    sellerName: sellerName,
    vatNumber: vatNumber,
    timestamp: posInvoiceTimestamp(result.placedAt ?? DateTime.now()),
    total: result.grandTotal.toStringAsFixed(2),
    vatAmount: result.invoiceVat.toStringAsFixed(2),
  );
}

/// ZATCA expects the timestamp tag as an ISO 8601 UTC instant.
String posInvoiceTimestamp(DateTime value) {
  final utc = value.toUtc();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
      '${two(utc.day)}T${two(utc.hour)}:${two(utc.minute)}:'
      '${two(utc.second)}Z';
}

/// The printable ZATCA Phase 1 simplified tax invoice of one counter sale.
String buildPosReceiptDocument(PosReceipt receipt) {
  final arabic = AppLocale.instance.isArabic;
  final language = arabic ? 'ar' : 'en';
  final direction = arabic ? 'rtl' : 'ltr';
  final result = receipt.result;

  final rows = StringBuffer();
  for (final line in receipt.lines) {
    final options = line.optionsLabel(AppLocale.instance.language);
    final note = line.note.trim();
    rows.write(
      '<tr>'
      '<td class="qty">${_escape(localizeDigits('${line.quantity}'))}</td>'
      '<td><strong>${_escape(line.product.nameFor(AppLocale.instance.language))}</strong>'
      '${options.isEmpty ? '' : '<div class="detail">${_escape(options)}</div>'}'
      '${note.isEmpty ? '' : '<div class="detail">${_escape(note)}</div>'}'
      '</td>'
      '<td class="num">${_escape(_money(line.unitPrice, receipt.currencyCode))}</td>'
      '<td class="num">${_escape(_money(line.lineTotal, receipt.currencyCode))}</td>'
      '</tr>',
    );
  }

  final table = result.tableNumber?.trim() ?? '';
  final customer = result.customerDisplayName;
  final customerPhone = result.customerPhone?.trim() ?? '';
  final details = <(String, String)>[
    (S.posInvoiceNumber, _escape(result.orderNumber)),
    (
      S.posInvoiceDateTime,
      _escape(posDateTime(result.placedAt ?? DateTime.now())),
    ),
    (S.posTable, _escape(table.isEmpty ? '-' : table)),
    if (customer.isNotEmpty) (S.posCustomer, _escape(customer)),
    if (customerPhone.isNotEmpty) (S.posCustomerPhone, _escape(customerPhone)),
    if (result.isSplitPayment)
      for (final tender in result.payments)
        (
          posTenderLabel(tender, AppLocale.instance.language),
          _escape(_money(tender.amount, receipt.currencyCode)),
        )
    else
      (
        S.posReceiptPaymentMethod,
        _escape(result.paymentMethodNameFor(AppLocale.instance.language)),
      ),
  ];
  final detailsHtml = details
      .map(
        (field) =>
            '<div class="field"><span>${_escape(field.$1)}</span>'
            '<strong>${field.$2}</strong></div>',
      )
      .join();

  final money = receipt.currencyCode;
  final totals = StringBuffer();
  if (result.discountAmount > 0) {
    totals
      ..write(_row(S.posBeforeDiscount, _money(result.beforeDiscount, money)))
      ..write(_row(S.posDiscount, '- ${_money(result.discountAmount, money)}'))
      ..write(_row(S.posAfterDiscount, _money(result.subtotal, money)));
  } else {
    totals.write(_row(S.posSubtotal, _money(result.subtotal, money)));
  }
  totals.write(_row(S.posTaxableAmount, _money(result.invoiceTaxable, money)));
  if (result.taxRate > 0) {
    totals.write(_row(S.posVatRate, posPercent(result.taxRate)));
  }
  totals.write(_row(S.posVatAmount, _money(result.invoiceVat, money)));
  totals.write(
    '<div class="row grand"><span>${_escape(S.posTotal)}</span>'
    '<strong>${_escape(_money(result.grandTotal, money))}</strong></div>',
  );

  final sellerName = result.sellerLegalNameFor(AppLocale.instance.language);
  final sellerAddress = result.sellerAddressFor(AppLocale.instance.language);
  final sellerVat = result.sellerVatNumber.trim();
  final sellerPhone = result.sellerPhone.trim();
  final sellerHtml = StringBuffer()
    ..write('<div class="seller-name">${_escape(sellerName)}</div>')
    ..write(
      sellerAddress.isEmpty
          ? ''
          : '<div class="meta">${_escape(sellerAddress)}</div>',
    )
    ..write(
      sellerVat.isEmpty
          ? ''
          : '<div class="meta">${_escape(S.posSellerVatNumber)}: '
                '${_escape(localizeDigits(sellerVat))}</div>',
    )
    ..write(
      sellerPhone.isEmpty
          ? ''
          : '<div class="meta">${_escape(sellerPhone)}</div>',
    );

  final qrData = buildPosReceiptQrData(receipt);
  final qrHtml = qrData == null
      ? '<section class="warning">${_escape(S.posVatNumberMissing)}</section>'
      : '<section class="qr">'
            '<div class="qr-image">${renderPosQrSvg(qrData)}</div>'
            '<div class="qr-caption">${_escape(S.posInvoiceQrCaption)}</div>'
            '</section>';

  final note = receipt.orderNote;
  final noteHtml = note.isEmpty
      ? ''
      : '<section class="note"><span>${_escape(S.posOrderNote)}</span>'
            '<p>${_escape(note)}</p></section>';

  return '''
<!DOCTYPE html>
<html dir="$direction" lang="$language">
<head>
<meta charset="utf-8">
<title>${_escape(S.posTaxInvoiceTitle)} - ${_escape(result.orderNumber)}</title>
<style>
  * { box-sizing: border-box; }
  body {
    margin: 0;
    padding: 24px;
    color: #22332d;
    background: #ffffff;
    font-family: 'IBM Plex Sans Arabic', 'Segoe UI', Tahoma, Arial, sans-serif;
  }
  .receipt { max-width: 640px; margin: 0 auto; }
  header {
    text-align: center;
    padding-bottom: 12px;
    margin-bottom: 14px;
    border-bottom: 2px solid #e6f1eb;
  }
  h1 { margin: 0 0 3px; font-size: 21px; }
  .invoice-title { margin: 0; font-size: 21px; font-weight: 700; }
  .invoice-subtitle { margin-top: 2px; color: #667085; font-size: 11px; }
  .seller {
    padding: 10px 12px;
    margin-bottom: 14px;
    border: 1px solid #eef1ef;
    border-radius: 9px;
    background: #fcfdfc;
  }
  .seller-name { font-size: 14px; font-weight: 700; margin-bottom: 2px; }
  .meta { color: #667085; font-size: 10.5px; line-height: 1.6; }
  .details {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 6px;
    margin-bottom: 16px;
  }
  .field {
    padding: 8px 10px;
    border: 1px solid #eef1ef;
    border-radius: 8px;
    background: #fcfdfc;
  }
  .field span {
    display: block;
    margin-bottom: 2px;
    color: #819087;
    font-size: 9.5px;
  }
  .field strong {
    display: block;
    color: #36473e;
    font-size: 11px;
    font-weight: 600;
    overflow-wrap: anywhere;
  }
  table { width: 100%; border-collapse: collapse; font-size: 11px; }
  th {
    padding: 7px 6px;
    text-align: start;
    font-weight: 700;
    color: #36473e;
    background: #f3f6f4;
    border-top: 1px solid #e3e9e4;
    border-bottom: 1px solid #e3e9e4;
    white-space: nowrap;
  }
  td {
    padding: 8px 6px;
    vertical-align: top;
    border-bottom: 1px solid #eef1ef;
  }
  td strong { display: block; font-size: 11.5px; }
  .qty { white-space: nowrap; color: #49584f; }
  .detail { margin-top: 2px; color: #819087; font-size: 10px; }
  .num { white-space: nowrap; text-align: end; font-variant-numeric: tabular-nums; }
  .totals { margin-top: 12px; padding: 10px 12px; border-radius: 9px; background: #f6faf7; }
  .row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 3px 0;
    color: #49584f;
    font-size: 11px;
  }
  .row strong { color: #36473e; }
  .row.grand { margin-top: 6px; padding-top: 8px; border-top: 1px solid #dce7e0; }
  .row.grand span { font-weight: 700; color: #22332d; }
  .row.grand strong { color: #087f68; font-size: 18px; }
  .qr {
    display: flex;
    align-items: center;
    gap: 14px;
    margin-top: 14px;
    padding: 11px 12px;
    border: 1px solid #dce7e0;
    border-radius: 9px;
  }
  .qr-image svg { display: block; width: 132px; height: 132px; }
  .qr-caption { color: #49584f; font-size: 10px; line-height: 1.7; }
  .warning {
    margin-top: 14px;
    padding: 9px 11px;
    border: 1px solid #f0c987;
    border-radius: 8px;
    background: #fff8e8;
    color: #7a5200;
    font-size: 10.5px;
    line-height: 1.7;
  }
  .note {
    margin-top: 12px;
    padding: 9px 11px;
    border: 1px dashed #dce7e0;
    border-radius: 8px;
    color: #49584f;
    font-size: 10.5px;
  }
  .note span { color: #819087; font-size: 9.5px; }
  .note p { margin: 3px 0 0; }
  footer {
    margin-top: 16px;
    padding-top: 10px;
    border-top: 1px solid #eef1ef;
    text-align: center;
    color: #819087;
    font-size: 10px;
    line-height: 1.6;
  }
  footer strong { display: block; margin-bottom: 3px; color: #087f68; font-size: 12px; }
  @page { size: A4 portrait; margin: 14mm; }
  @media print {
    body { padding: 0; }
    * { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  }
</style>
</head>
<body>
<div class="receipt">
<header>
  <div class="invoice-title">${_escape(S.posTaxInvoiceTitle)}</div>
  <div class="invoice-subtitle">${_escape(S.posTaxInvoiceTitleAlt)}</div>
</header>
<section class="seller">
  $sellerHtml
</section>
<div class="details">
$detailsHtml
</div>
<table>
  <thead>
    <tr>
      <th>${_escape(S.posQuantity)}</th>
      <th>${_escape(S.posItems)}</th>
      <th class="num">${_escape(S.posPrice)}</th>
      <th class="num">${_escape(S.posTotal)}</th>
    </tr>
  </thead>
  <tbody>
$rows
  </tbody>
</table>
<div class="totals">
  $totals
</div>
$qrHtml
$noteHtml
<footer>
  <strong>${_escape(S.posReceiptThanks)}</strong>
  <div>${_escape(S.posTaxInvoiceCompliance)}</div>
  ${_date(DateTime.now())}
</footer>
</div>
</body>
</html>
''';
}

String _row(String label, String value) =>
    '<div class="row"><span>${_escape(label)}</span>'
    '<strong>${_escape(value)}</strong></div>';

String _money(num amount, String currency) =>
    '${localizeDigits(formatAmount(amount))} ${_escape(currency)}';

String _date(DateTime value) => _escape(localizeDigits(formatDateTime(value)));

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
