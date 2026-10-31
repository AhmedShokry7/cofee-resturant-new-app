import 'dart:ui' show Color;

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:admin_app/core/theme/app_color.dart';

/// الطباعة على كل الأهداف من مسار واحد: المستند يُرسم PDFًا في التطبيق ثم
/// يُسلَّم إلى نافذة الطباعة عند نظام التشغيل، إلى معاينة الطباعة على Android
/// وiOS، وإلى إطار الطباعة على الويب. لا جهاز يحتاج متصفحًا مفتوحًا بعد اليوم.
abstract final class AppPdf {
  AppPdf._();

  static const String _regular = 'assets/fonts/IBMPlexSansArabic-Regular.ttf';
  static const String _bold = 'assets/fonts/IBMPlexSansArabic-Bold.ttf';

  static final Map<String, Future<pw.Font>> _fonts =
      <String, Future<pw.Font>>{};

  /// الخط العربي نفسه الذي تُعرض به اللوحة، مسجَّلًا داخل الملف: بلا خط مضمَّن
  /// تُرسم الحروف العربية مربّعات أو تُترك صفراء، لأن PDF لا يحمل خطوط النظام.
  static Future<pw.Font> _load(String asset) =>
      _fonts.putIfAbsent(asset, () async {
        final data = await rootBundle.load(asset);
        return pw.Font.ttf(data);
      });

  static Future<pw.ThemeData> theme() async => pw.ThemeData.withFont(
    base: await _load(_regular),
    bold: await _load(_bold),
  );

  static PdfColor get ink => _of(AppColor.adminHeading);
  static PdfColor get body => _of(AppColor.adminBody);
  static PdfColor get amount => _of(AppColor.adminAmount);
  static PdfColor get muted => _of(AppColor.adminMuted);
  static PdfColor get faint => _of(AppColor.greyColor);
  static PdfColor get accent => _of(AppColor.primaryColor);
  static PdfColor get hairline => _of(AppColor.adminControlBorder);
  static PdfColor get edge => _of(AppColor.adminAccentSurface);
  static PdfColor get surface => _of(AppColor.adminRowSelected);
  static PdfColor get panel => _of(AppColor.adminAccentSurface);
  static PdfColor get warning => _of(AppColor.adminWarning);
  static PdfColor get warningSurface => _of(AppColor.adminWarningSurface);

  static PdfColor _of(Color value) =>
      PdfColor(value.r, value.g, value.b, value.a);

  /// Opens the platform print dialog with [document] and reports whether the
  /// job was handed over. `dynamicLayout` stays off: the page was laid out for
  /// one paper size, so re-laying it out per printer would reflow the invoice.
  static Future<bool> print(
    pw.Document document, {
    required String name,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    try {
      final bytes = await document.save();
      return await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: name,
        format: format,
        dynamicLayout: false,
      );
    } catch (_) {
      return false;
    }
  }
}
