import 'package:pdf/widgets.dart' as pw;

import 'package:admin_app/core/services/app_pdf.dart';

/// الأشكال التي تتكرر في كل مستند مطبوع: خانة بعنوان وقيمة، وسطر مجموع، ولوحة
/// محاطة، وعنوان قسم. تُكتب مرة واحدة حتى لا يختلف كشف الدفع عن فاتورة
/// الكاشير في نفس السمة، وكي يبقى الورق أقرب ما يكون إلى شاشة اللوحة.
///
/// الألوان كلها من `AppPdf` الذي يأخذها من `AppColor`، فلا رقم لون هنا.
abstract final class AppPdfLayout {
  AppPdfLayout._();

  static const double gap = 6;

  static pw.TextStyle labelStyle() =>
      pw.TextStyle(fontSize: 8.5, color: AppPdf.muted);

  static pw.TextStyle valueStyle({bool strong = true}) => pw.TextStyle(
    fontSize: strong ? 10 : 9.5,
    fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: strong ? AppPdf.amount : AppPdf.body,
  );

  static pw.TextStyle sectionStyle() => pw.TextStyle(
    fontSize: 11,
    fontWeight: pw.FontWeight.bold,
    color: AppPdf.amount,
  );

  /// خانة واحدة: تسمية صغيرة فوقها وقيمتها تحتها، داخل إطار فاتح.
  static pw.Widget field(String label, String value) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: AppPdf.hairline),
      borderRadius: pw.BorderRadius.circular(6),
      color: AppPdf.panel,
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: labelStyle()),
        pw.SizedBox(height: 2),
        pw.Text(value, style: valueStyle(), maxLines: 3),
      ],
    ),
  );

  /// حقول في شبكة من عمودين؛ الصف الفردي يأخذ عرضه كاملًا كي لا يضيق النص.
  static pw.Widget fieldGrid(List<(String, String)> fields) {
    final rows = <pw.Widget>[];
    for (var index = 0; index < fields.length; index += 2) {
      final hasPair = index + 1 < fields.length;
      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: field(fields[index].$1, fields[index].$2)),
            if (hasPair) ...[
              pw.SizedBox(width: gap),
              pw.Expanded(
                child: field(fields[index + 1].$1, fields[index + 1].$2),
              ),
            ],
          ],
        ),
      );
      if (index + 2 < fields.length) {
        rows.add(pw.SizedBox(height: gap));
      }
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  /// سطر «التسمية … القيمة» كما في صندوق المجاميع.
  static pw.Widget summaryRow(
    String label,
    String value, {
    bool grand = false,
  }) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    decoration: grand
        ? pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: AppPdf.edge)),
          )
        : null,
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: grand ? 11 : 9.5,
              fontWeight: grand ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: grand ? AppPdf.ink : AppPdf.body,
            ),
          ),
        ),
        pw.SizedBox(width: gap),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: grand ? 14 : 9.5,
            fontWeight: pw.FontWeight.bold,
            color: grand ? AppPdf.accent : AppPdf.amount,
          ),
        ),
      ],
    ),
  );

  /// لوحة بعنوان وخلفية فاتحة، تحيط بمجموعة أسطر.
  static pw.Widget panel(List<pw.Widget> children, {String? title}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: AppPdf.surface,
          border: pw.Border.all(color: AppPdf.edge),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              pw.Text(title, style: sectionStyle()),
              pw.SizedBox(height: 6),
            ],
            ...children,
          ],
        ),
      );

  /// ترويسة المستند: عنوان وسطر تحته، كما في فاتورة الكاشير.
  static pw.Widget documentHeader(String title, String subtitle) =>
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: AppPdf.edge, width: 2),
          ),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(subtitle, style: labelStyle()),
          ],
        ),
      );

  /// خلية جدول: الحشو والمحاذاة هنا حتى تتساوى كل الجداول المطبوعة.
  static pw.Widget cell(
    String text, {
    bool header = false,
    bool strong = false,
    bool numeric = false,
  }) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
    color: header ? AppPdf.edge : null,
    child: pw.Text(
      text,
      textAlign: numeric
          ? pw.TextAlign.end
          : header
          ? pw.TextAlign.end
          : pw.TextAlign.start,
      style: pw.TextStyle(
        fontSize: header ? 9 : 9.5,
        fontWeight: header || strong
            ? pw.FontWeight.bold
            : pw.FontWeight.normal,
        color: header ? AppPdf.amount : AppPdf.ink,
      ),
    ),
  );

  static pw.TableBorder tableBorder() => pw.TableBorder(
    top: pw.BorderSide(color: AppPdf.hairline),
    bottom: pw.BorderSide(color: AppPdf.hairline),
    horizontalInside: pw.BorderSide(color: AppPdf.hairline),
  );
}
