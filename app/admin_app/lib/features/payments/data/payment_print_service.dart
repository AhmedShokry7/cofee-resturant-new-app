import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/payments/data/models/admin_payment.dart';
import 'package:admin_app/core/services/html_print_runner.dart';

/// Opens the browser print dialog with a statement of [payments].
///
/// The statement is written into a hidden frame so the browser can print it
/// with the Arabic or English layout of the panel, without a PDF dependency.
class PaymentPrintService {
  PaymentPrintService._();

  static Future<bool> printPayments(List<AdminPayment> payments) async {
    if (payments.isEmpty) return false;
    return printHtmlDocument(buildPaymentPrintDocument(payments));
  }

  /// Prints a single transaction as its own receipt.
  static Future<bool> printPayment(AdminPayment payment) =>
      printHtmlDocument(buildPaymentReceiptDocument(payment));
}

/// The printable receipt of one payment transaction, in the language of the
/// panel.
String buildPaymentReceiptDocument(AdminPayment payment) {
  final arabic = AppLocale.instance.isArabic;
  final direction = arabic ? 'rtl' : 'ltr';
  final language = arabic ? 'ar' : 'en';
  final order = payment.orderNumber?.trim();
  final customer = payment.customerName?.trim();
  final reference = payment.providerReference?.trim();
  final holder = payment.cardHolderName?.trim();
  final status = S.paymentStatusLabel(payment.status);

  final fields = <(String, String)>[
    (
      S.orderNumber,
      _escape(order == null || order.isEmpty ? payment.id : order),
    ),
    (
      S.customer,
      _escape(
        customer == null || customer.isEmpty ? S.unknownCustomer : customer,
      ),
    ),
    (S.provider, _escape(payment.provider)),
    (
      S.reference,
      _escape(reference == null || reference.isEmpty ? '-' : reference),
    ),
    (S.paymentStatusLabelTitle, _escape(status)),
    (S.paidAt, _date(payment.paidAt)),
    (S.refundedAt, _date(payment.refundedAt)),
    (S.paymentCard, _escape(_cardLabel(payment) ?? '-')),
    (
      S.paymentCardHolder,
      _escape(holder == null || holder.isEmpty ? '-' : holder),
    ),
    (S.verifiedByServer, _escape(payment.verifiedByServer ? S.yes : S.no)),
    (S.createdAt, _date(payment.createdAt)),
  ];

  final fieldsHtml = fields
      .map(
        (field) =>
            '<div class="field"><span>${_escape(field.$1)}</span>'
            '<strong>${field.$2}</strong></div>',
      )
      .join();

  return '''
<!DOCTYPE html>
<html dir="$direction" lang="$language">
<head>
<meta charset="utf-8">
<title>${_escape(S.paymentReceiptTitle)}</title>
<style>
  * { box-sizing: border-box; }
  body {
    margin: 0;
    padding: 24px;
    color: #22332d;
    background: #ffffff;
    font-family: 'IBM Plex Sans Arabic', 'Segoe UI', Tahoma, Arial, sans-serif;
  }
  .receipt { max-width: 680px; margin: 0 auto; }
  header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 16px;
    padding-bottom: 12px;
    margin-bottom: 18px;
    border-bottom: 2px solid #e6f1eb;
  }
  h1 { margin: 0 0 4px; font-size: 22px; }
  .meta { color: #667085; font-size: 11px; }
  .status {
    display: inline-block;
    padding: 5px 10px;
    border: 1px solid #dce7e0;
    border-radius: 999px;
    background: #f6faf7;
    color: #087f68;
    font-size: 11px;
    font-weight: 700;
    white-space: nowrap;
  }
  .amount {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    padding: 14px 16px;
    margin-bottom: 16px;
    border: 1px solid #e6f1eb;
    border-radius: 10px;
    background: #f6faf7;
  }
  .amount span { color: #49584f; font-size: 11px; }
  .amount strong { color: #087f68; font-size: 26px; line-height: 1.2; }
  h2 {
    margin: 0 0 10px;
    color: #36473e;
    font-size: 13px;
  }
  .grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
  }
  .field {
    padding: 9px 12px;
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
    font-size: 11.5px;
    font-weight: 600;
    overflow-wrap: anywhere;
  }
  footer {
    margin-top: 18px;
    padding-top: 10px;
    border-top: 1px solid #eef1ef;
    color: #819087;
    font-size: 10px;
  }
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
  <div>
    <h1>${_escape(S.paymentReceiptTitle)}</h1>
    <div class="meta">${_escape(S.paymentTransactionNumber)}: ${_escape(payment.id)}</div>
  </div>
  <div class="status">${_escape(status)}</div>
</header>
<div class="amount">
  <span>${_escape(S.amount)}</span>
  <strong>${_money(payment.amount, payment.currencyCode)}</strong>
</div>
<h2>${_escape(S.paymentReceiptDetails)}</h2>
<div class="grid">
$fieldsHtml
</div>
<footer>${_escape(S.paymentsPrintGeneratedAt)}: ${_date(DateTime.now())}</footer>
</div>
</body>
</html>
''';
}

/// The printable HTML statement of [payments], in the language of the panel.
String buildPaymentPrintDocument(List<AdminPayment> payments) {
  final arabic = AppLocale.instance.isArabic;
  final direction = arabic ? 'rtl' : 'ltr';
  final language = arabic ? 'ar' : 'en';

  final rows = StringBuffer();
  for (final payment in payments) {
    final order = payment.orderNumber?.trim();
    final customer = payment.customerName?.trim();
    rows.write(
      '<tr>'
      '<td>${_escape(order == null || order.isEmpty ? payment.id : order)}</td>'
      '<td>${_escape(customer == null || customer.isEmpty ? S.unknownCustomer : customer)}</td>'
      '<td>${_escape(payment.provider)}</td>'
      '<td>${_escape(payment.providerReference?.trim() ?? '-')}</td>'
      '<td class="num">${_money(payment.amount, payment.currencyCode)}</td>'
      '<td class="status">${_escape(S.paymentStatusLabel(payment.status))}</td>'
      '<td class="num">${_date(payment.paidAt ?? payment.createdAt)}</td>'
      '<td>${_escape(_cardLabel(payment) ?? '-')}</td>'
      '</tr>',
    );
  }
  if (payments.isEmpty) {
    rows.write(
      '<tr><td colspan="8" class="empty">${_escape(S.noPaymentsYet)}</td></tr>',
    );
  }

  final totals = <String, double>{};
  for (final payment in payments) {
    if (payment.status != 'captured') continue;
    totals.update(
      payment.currencyCode,
      (value) => value + payment.amount,
      ifAbsent: () => payment.amount,
    );
  }
  final totalsHtml = totals.isEmpty
      ? ''
      : '<div class="summary">'
            '<span>${_escape(S.paymentsPrintCollected)}</span>'
            '<strong>${totals.entries.map((entry) => _money(entry.value, entry.key)).join(' • ')}</strong>'
            '</div>';

  return '''
<!DOCTYPE html>
<html dir="$direction" lang="$language">
<head>
<meta charset="utf-8">
<title>${_escape(S.paymentsPrintTitle)}</title>
<style>
  * { box-sizing: border-box; }
  body {
    margin: 0;
    padding: 24px;
    color: #22332d;
    background: #ffffff;
    font-family: 'IBM Plex Sans Arabic', 'Segoe UI', Tahoma, Arial, sans-serif;
  }
  header {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    gap: 16px;
    padding-bottom: 10px;
    margin-bottom: 14px;
    border-bottom: 2px solid #e6f1eb;
  }
  h1 { margin: 0 0 4px; font-size: 20px; }
  .meta, .count { color: #667085; font-size: 11px; }
  .summary {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 9px 12px;
    margin-bottom: 12px;
    border: 1px solid #e6f1eb;
    border-radius: 8px;
    background: #f6faf7;
    font-size: 11px;
    color: #49584f;
  }
  .summary strong { color: #087f68; font-size: 13px; }
  table { width: 100%; border-collapse: collapse; font-size: 10.5px; }
  thead { display: table-header-group; }
  th {
    padding: 7px 6px;
    text-align: start;
    font-weight: 700;
    color: #36473e;
    background: #f3f6f4;
    border: 1px solid #e3e9e4;
    white-space: nowrap;
  }
  td {
    padding: 6px;
    vertical-align: top;
    border: 1px solid #eef1ef;
  }
  tbody tr:nth-child(even) { background: #fafcfb; }
  tr { page-break-inside: avoid; }
  .num { white-space: nowrap; font-variant-numeric: tabular-nums; }
  .status { white-space: nowrap; }
  .empty { padding: 20px; text-align: center; color: #667085; }
  @page { size: A4 landscape; margin: 12mm; }
  @media print {
    body { padding: 0; }
    * { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  }
</style>
</head>
<body>
<header>
  <div>
    <h1>${_escape(S.paymentsPrintTitle)}</h1>
    <div class="meta">${_escape(S.paymentsPrintGeneratedAt)}: ${_date(DateTime.now())}</div>
  </div>
  <div class="count">${_escape(S.paymentsPrintCount(payments.length))}</div>
</header>
$totalsHtml
<table>
  <thead>
    <tr>
      <th>${_escape(S.orderNumber)}</th>
      <th>${_escape(S.customer)}</th>
      <th>${_escape(S.provider)}</th>
      <th>${_escape(S.reference)}</th>
      <th>${_escape(S.amount)}</th>
      <th>${_escape(S.paymentStatusLabelTitle)}</th>
      <th>${_escape(S.paidAt)}</th>
      <th>${_escape(S.paymentCard)}</th>
    </tr>
  </thead>
  <tbody>
$rows
  </tbody>
</table>
</body>
</html>
''';
}

String _money(num amount, String currency) =>
    '${localizeDigits(formatAmount(amount))} ${_escape(currency)}';

String _date(DateTime? value) =>
    value == null ? '-' : _escape(localizeDigits(formatDateTime(value)));

String? _cardLabel(AdminPayment payment) {
  final brand = payment.cardBrand?.trim() ?? '';
  final last4 = payment.cardLast4?.trim() ?? '';
  if (last4.isEmpty) return brand.isEmpty ? null : brand;
  return brand.isEmpty ? '•••• $last4' : '$brand •••• $last4';
}

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
