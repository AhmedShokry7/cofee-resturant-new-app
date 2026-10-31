import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/services/app_pdf.dart';
import 'package:admin_app/core/services/app_pdf_layout.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/payments/data/models/admin_payment.dart';

/// يفتح طباعة النظام بكشف أو إيصال، على ويندوز وmacOS وLinux وAndroid وiOS
/// والويب من نفس المسار: المستند يُرسم PDFًا ثم يُسلَّم إلى نافذة الطباعة.
class PaymentPrintService {
  PaymentPrintService._();

  static Future<bool> printPayments(List<AdminPayment> payments) async {
    if (payments.isEmpty) return false;
    return AppPdf.print(
      await buildPaymentStatementDocument(payments),
      name: S.paymentsPrintTitle,
      format: PdfPageFormat.a4.landscape,
    );
  }

  /// Prints a single transaction as its own receipt.
  static Future<bool> printPayment(AdminPayment payment) async => AppPdf.print(
    await buildPaymentReceiptDocument(payment),
    name: S.paymentReceiptTitle,
  );
}

/// الخانات المطبوعة لإيداع واحد، بترتيبها: ما يُقرأ في الورق هو نفسه ما
/// يقيسه الاختبار، بلا وساطة لغة توصيف.
List<(String, String)> paymentReceiptFields(AdminPayment payment) {
  final order = payment.orderNumber?.trim();
  final customer = payment.customerName?.trim();
  final reference = payment.providerReference?.trim();
  final holder = payment.cardHolderName?.trim();

  return <(String, String)>[
    (S.orderNumber, order == null || order.isEmpty ? payment.id : order),
    (
      S.customer,
      customer == null || customer.isEmpty ? S.unknownCustomer : customer,
    ),
    (S.provider, payment.provider),
    (S.reference, reference == null || reference.isEmpty ? '-' : reference),
    (S.paymentStatusLabelTitle, S.paymentStatusLabel(payment.status)),
    (S.paidAt, _date(payment.paidAt)),
    (S.refundedAt, _date(payment.refundedAt)),
    (S.paymentCard, _cardLabel(payment) ?? '-'),
    (S.paymentCardHolder, holder == null || holder.isEmpty ? '-' : holder),
    (S.verifiedByServer, payment.verifiedByServer ? S.yes : S.no),
    (S.createdAt, _date(payment.createdAt)),
  ];
}

/// إيصال عملية واحدة على A4 رأسي، بلغة اللوحة واتجاهها.
Future<pw.Document> buildPaymentReceiptDocument(AdminPayment payment) async {
  final arabic = AppLocale.instance.isArabic;
  final status = S.paymentStatusLabel(payment.status);
  final document = pw.Document(
    theme: await AppPdf.theme(),
    title: S.paymentReceiptTitle,
  );

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      textDirection: arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      build: (context) => pw.Padding(
        padding: const pw.EdgeInsets.all(32),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        S.paymentReceiptTitle,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: AppPdf.ink,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        '${S.paymentTransactionNumber}: ${payment.id}',
                        style: AppPdfLayout.labelStyle(),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: AppPdf.edge),
                    borderRadius: pw.BorderRadius.circular(20),
                    color: AppPdf.surface,
                  ),
                  child: pw.Text(
                    status,
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: AppPdf.accent,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: AppPdf.edge),
                borderRadius: pw.BorderRadius.circular(9),
                color: AppPdf.surface,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    S.amount,
                    style: pw.TextStyle(fontSize: 10, color: AppPdf.body),
                  ),
                  pw.Text(
                    _money(payment.amount, payment.currencyCode),
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: AppPdf.accent,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              S.paymentReceiptDetails,
              style: AppPdfLayout.sectionStyle(),
            ),
            pw.SizedBox(height: 6),
            AppPdfLayout.fieldGrid(paymentReceiptFields(payment)),
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 16),
              padding: const pw.EdgeInsets.only(top: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: AppPdf.hairline)),
              ),
              child: pw.Text(
                '${S.paymentsPrintGeneratedAt}: ${_date(DateTime.now())}',
                style: pw.TextStyle(fontSize: 9, color: AppPdf.muted),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return document;
}

/// سطور الكشف: ثمانية أعمدة نصية جاهزة للورق دون أي تحويل وسطي.
List<List<String>> paymentStatementRows(List<AdminPayment> payments) => [
  for (final payment in payments)
    [
      payment.orderNumber?.trim() ?? '',
      payment.customerName?.trim() ?? '',
      payment.provider,
      payment.providerReference?.trim() ?? '',
      _money(payment.amount, payment.currencyCode),
      S.paymentStatusLabel(payment.status),
      _date(payment.paidAt ?? payment.createdAt),
      _cardLabel(payment) ?? '',
    ].map(_orDash).toList(),
];

/// ترويسة أعمدة الكشف، بلغة اللوحة وقت الطباعة.
List<String> paymentStatementHeaders() => <String>[
  S.orderNumber,
  S.customer,
  S.provider,
  S.reference,
  S.amount,
  S.paymentStatusLabelTitle,
  S.paidAt,
  S.paymentCard,
];

/// جدول الكشف كله في عنصر واحد: `pw.Table` يقدر يمتد على صفحات `MultiPage`
/// تلقائيًا، فالسطور الكثيرة لا تُقطع عند نهاية الصفحة الأولى ولا تختلف
/// أعرضتها بين صفحة وأخرى.
pw.Widget _statementTable(List<List<String>> rows) => pw.Table(
  border: AppPdfLayout.tableBorder(),
  children: [
    pw.TableRow(
      children: [
        for (final label in paymentStatementHeaders())
          AppPdfLayout.cell(label, header: true),
      ],
    ),
    for (final row in rows)
      pw.TableRow(
        children: [
          for (var column = 0; column < row.length; column++)
            AppPdfLayout.cell(
              row[column],
              numeric: column == 4 || column == 6,
              strong: column == 0,
            ),
        ],
      ),
  ],
);

/// مجموع ما حُصَّل لكل عملة، أو null حين لا شيء: بلا أرقام مختلَقة.
String? paymentStatementCollected(List<AdminPayment> payments) {
  final totals = <String, double>{};
  for (final payment in payments) {
    if (payment.status != 'captured') continue;
    totals.update(
      payment.currencyCode,
      (value) => value + payment.amount,
      ifAbsent: () => payment.amount,
    );
  }
  if (totals.isEmpty) return null;
  return totals.entries
      .map((entry) => _money(entry.value, entry.key))
      .join(' • ');
}

/// كشف A4 أفقي متعدد الصفحات: الترويسة مرة واحدة ثم جدول يمتد مع الصفحات،
/// فلا ينقطع السرد في الصفحة الثانية ولا يضيع عمود بين صفحة وأخرى.
Future<pw.Document> buildPaymentStatementDocument(
  List<AdminPayment> payments,
) async {
  final arabic = AppLocale.instance.isArabic;
  final rows = paymentStatementRows(payments);
  final collected = paymentStatementCollected(payments);
  final document = pw.Document(
    theme: await AppPdf.theme(),
    title: S.paymentsPrintTitle,
  );

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      textDirection: arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      build: (context) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  S.paymentsPrintTitle,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: AppPdf.ink,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  '${S.paymentsPrintGeneratedAt}: ${_date(DateTime.now())}',
                  style: AppPdfLayout.labelStyle(),
                ),
              ],
            ),
            pw.Text(
              S.paymentsPrintCount(payments.length),
              style: AppPdfLayout.labelStyle(),
            ),
          ],
        ),
        if (collected != null) ...[
          pw.SizedBox(height: 10),
          AppPdfLayout.panel([
            AppPdfLayout.summaryRow(S.paymentsPrintCollected, collected),
          ]),
        ],
        pw.SizedBox(height: 12),
        if (rows.isEmpty)
          pw.Text(
            S.noPaymentsYet,
            style: pw.TextStyle(fontSize: 10, color: AppPdf.faint),
          ),
        _statementTable(rows),
      ],
    ),
  );
  return document;
}

String _orDash(String value) => value.trim().isEmpty ? '-' : value.trim();

String _money(num amount, String currency) =>
    '${localizeDigits(formatAmount(amount))} $currency';

String _date(DateTime? value) =>
    value == null ? '-' : localizeDigits(formatDateTime(value));

String? _cardLabel(AdminPayment payment) {
  final brand = payment.cardBrand?.trim() ?? '';
  final last4 = payment.cardLast4?.trim() ?? '';
  if (last4.isEmpty) return brand.isEmpty ? null : brand;
  return brand.isEmpty ? '•••• $last4' : '$brand •••• $last4';
}
