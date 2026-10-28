import 'package:file_picker/file_picker.dart';

import 'package:admin_app/core/services/product_excel_service.dart';

/// The one place a directory turns its rows into a downloadable workbook.
///
/// Every directory that exports (orders, payments, customers) asked for the
/// same three steps — build, stamp the date into the name, offer a save
/// dialog — so the steps live here and the pages keep only their columns.
class ExcelReportSaver {
  const ExcelReportSaver._();

  /// Writes [rows] as a .xlsx offered under `<baseName>-<date>.xlsx`.
  ///
  /// Returns false when the visitor closes the dialog instead of saving, which
  /// the calling page reports as "nothing happened" rather than a failure.
  static Future<bool> save({
    required List<List<String>> rows,
    required String dialogTitle,
    required String baseName,
  }) async {
    final date = DateTime.now().toIso8601String().split('T').first;
    final path = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: '$baseName-$date.xlsx',
      bytes: ProductExcelService.buildWorkbook(rows),
    );
    return path != null;
  }
}
