import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/services/app_pdf.dart';
import 'package:admin_app/core/services/app_pdf_layout.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/pos/domain/entities/pos_receipt.dart';
import 'package:admin_app/features/pos/data/pos_invoice_qr.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_format.dart';

/// فاتورة الضريبية المبسطة تُطبع من نفس المسار على كل الأجهزة: تُرسم PDFًا
/// وتُسلَّم إلى نافذة طباعة النظام (أو إلى معاينة الطباعة على الهاتف).
Future<bool> printPosReceipt(PosReceipt receipt) async => AppPdf.print(
  await buildPosReceiptDocument(receipt),
  name: '${S.posTaxInvoiceTitle} ${receipt.result.orderNumber}',
);

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

/// بيانات البائع كما تُطبع أعلى الفاتورة: الاسم ثم ما وُضع من عنوان ورقم
/// ضريبي وهاتف، بلا أسطر فارغة.
List<String> posReceiptSellerLines(PosReceipt receipt) {
  final result = receipt.result;
  final language = AppLocale.instance.language;
  return <String>[
    result.sellerLegalNameFor(language),
    result.sellerAddressFor(language),
    if (result.sellerVatNumber.trim().isNotEmpty)
      '${S.posSellerVatNumber}: ${localizeDigits(result.sellerVatNumber.trim())}',
    result.sellerPhone,
  ].map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
}

/// خانات الفاتورة: رقمها وتاريخها والطاولة والعميل ووسيلة الدفع أو دفعات
/// مقسّمة، وهي نفسها ما يقيسه الاختبار.
List<(String, String)> posReceiptDetails(PosReceipt receipt) {
  final result = receipt.result;
  final language = AppLocale.instance.language;
  final table = result.tableNumber?.trim() ?? '';
  final customer = result.customerDisplayName;
  final customerPhone = result.customerPhone?.trim() ?? '';
  return <(String, String)>[
    (S.posInvoiceNumber, result.orderNumber),
    (S.posInvoiceDateTime, posDateTime(result.placedAt ?? DateTime.now())),
    (S.posTable, table.isEmpty ? '-' : table),
    if (customer.isNotEmpty) (S.posCustomer, customer),
    if (customerPhone.isNotEmpty) (S.posCustomerPhone, customerPhone),
    if (result.isSplitPayment)
      for (final tender in result.payments)
        (
          posTenderLabel(tender, language),
          _money(tender.amount, receipt.currencyCode),
        )
    else
      (S.posReceiptPaymentMethod, result.paymentMethodNameFor(language)),
  ];
}

/// أسطر الأصناف: الكمية والاسم مع خياراته وملاحظته، ثم سعر الوحدة والإجمالي.
List<PosReceiptPrintLine> posReceiptPrintLines(PosReceipt receipt) {
  final language = AppLocale.instance.language;
  return [
    for (final line in receipt.lines)
      PosReceiptPrintLine(
        quantity: localizeDigits('${line.quantity}'),
        name: line.product.nameFor(language),
        details: <String>[
          line.optionsLabel(language),
          line.note.trim(),
        ].where((value) => value.isNotEmpty).toList(),
        unitPrice: _money(line.unitPrice, receipt.currencyCode),
        lineTotal: _money(line.lineTotal, receipt.currencyCode),
      ),
  ];
}

/// مجاميع الفاتورة بترتيبها، وآخرها الإجمالي البارز.
List<(String, String, bool)> posReceiptTotals(PosReceipt receipt) {
  final result = receipt.result;
  final money = receipt.currencyCode;
  return <(String, String, bool)>[
    if (result.discountAmount > 0) ...[
      (S.posBeforeDiscount, _money(result.beforeDiscount, money), false),
      (S.posDiscount, '- ${_money(result.discountAmount, money)}', false),
      (S.posAfterDiscount, _money(result.subtotal, money), false),
    ] else
      (S.posSubtotal, _money(result.subtotal, money), false),
    (S.posTaxableAmount, _money(result.invoiceTaxable, money), false),
    if (result.taxRate > 0) (S.posVatRate, posPercent(result.taxRate), false),
    (S.posVatAmount, _money(result.invoiceVat, money), false),
    (S.posTotal, _money(result.grandTotal, money), true),
  ];
}

/// سطر صنف واحد جاهز للورق، بلا أي وساطة لغة توصيف.
class PosReceiptPrintLine {
  const PosReceiptPrintLine({
    required this.quantity,
    required this.name,
    required this.details,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String quantity;
  final String name;
  final List<String> details;
  final String unitPrice;
  final String lineTotal;
}

/// فاتورة A4 رأسية بلغة اللوحة واتجاهها، تحمل رمز QR حين اكتملت هوية البائع.
Future<pw.Document> buildPosReceiptDocument(PosReceipt receipt) async {
  final arabic = AppLocale.instance.isArabic;
  final result = receipt.result;
  final qrData = buildPosReceiptQrData(receipt);
  final note = receipt.orderNote.trim();
  final sellerLines = posReceiptSellerLines(receipt);
  final document = pw.Document(
    theme: await AppPdf.theme(),
    title: '${S.posTaxInvoiceTitle} ${result.orderNumber}',
  );

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      textDirection: arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      build: (context) => pw.Padding(
        padding: const pw.EdgeInsets.all(28),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              S.posTaxInvoiceTitle,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(
                fontSize: 17,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              S.posTaxInvoiceTitleAlt,
              textAlign: pw.TextAlign.center,
              style: AppPdfLayout.labelStyle(),
            ),
            pw.SizedBox(height: 12),
            if (sellerLines.isNotEmpty) ...[
              AppPdfLayout.panel([
                for (final (index, line) in sellerLines.indexed)
                  pw.Text(
                    line,
                    style: pw.TextStyle(
                      fontSize: index == 0 ? 12 : 9,
                      fontWeight: index == 0
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      color: index == 0 ? AppPdf.ink : AppPdf.faint,
                    ),
                  ),
              ]),
              pw.SizedBox(height: 12),
            ],
            AppPdfLayout.fieldGrid(posReceiptDetails(receipt)),
            pw.SizedBox(height: 14),
            pw.Table(
              border: AppPdfLayout.tableBorder(),
              children: [
                pw.TableRow(
                  children: [
                    AppPdfLayout.cell(S.posQuantity, header: true),
                    AppPdfLayout.cell(S.posItems, header: true),
                    AppPdfLayout.cell(S.posPrice, header: true, numeric: true),
                    AppPdfLayout.cell(S.posTotal, header: true, numeric: true),
                  ],
                ),
                for (final line in posReceiptPrintLines(receipt))
                  pw.TableRow(
                    children: [
                      AppPdfLayout.cell(line.quantity),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 5,
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              line.name,
                              style: const pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            for (final detail in line.details)
                              pw.Text(
                                detail,
                                style: pw.TextStyle(
                                  fontSize: 8.5,
                                  color: AppPdf.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      AppPdfLayout.cell(line.unitPrice, numeric: true),
                      AppPdfLayout.cell(line.lineTotal, numeric: true),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 12),
            AppPdfLayout.panel([
              for (final (label, value, grand) in posReceiptTotals(receipt))
                AppPdfLayout.summaryRow(label, value, grand: grand),
            ]),
            if (qrData != null) ...[
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: AppPdf.edge),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: qrData,
                      width: 92,
                      height: 92,
                      color: AppPdf.ink,
                      // رمز ZATCA للتحقق الآلي، فلا يُطبع محتواه Base64 تحت المربع.
                      drawText: false,
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Text(
                        S.posInvoiceQrCaption,
                        style: pw.TextStyle(fontSize: 9, color: AppPdf.body),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (qrData == null) ...[
              pw.SizedBox(height: 12),
              AppPdfLayout.panel([
                pw.Text(
                  S.posVatNumberMissing,
                  style: pw.TextStyle(fontSize: 9.5, color: AppPdf.warning),
                ),
              ]),
            ],
            if (note.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              AppPdfLayout.panel([
                pw.Text(note, style: pw.TextStyle(fontSize: 9.5)),
              ], title: S.posOrderNote),
            ],
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 16),
              padding: const pw.EdgeInsets.only(top: 9),
              decoration: pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: AppPdf.hairline)),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    S.posReceiptThanks,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: AppPdf.accent,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    S.posTaxInvoiceCompliance,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 8.5, color: AppPdf.muted),
                  ),
                  pw.Text(
                    _date(DateTime.now()),
                    style: pw.TextStyle(fontSize: 8.5, color: AppPdf.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return document;
}

String _money(num amount, String currency) =>
    '${localizeDigits(formatAmount(amount))} $currency';

String _date(DateTime value) => localizeDigits(formatDateTime(value));
