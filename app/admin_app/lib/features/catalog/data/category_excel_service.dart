import 'dart:typed_data';

import 'package:admin_app/core/services/product_excel_service.dart';

/// Reads and writes categories to .xlsx format.
class CategoryExcelService {
  CategoryExcelService._();

  static const List<String> headers = <String>[
    'ID',
    'Name (Arabic)',
    'Name (English)',
    'Description (Arabic)',
    'Description (English)',
    'Active',
  ];

  /// Builds a real .xlsx file from a list of rows.
  static Uint8List buildWorkbook(List<List<String>> rows) {
    return ProductExcelService.buildWorkbook(rows);
  }

  /// Reads the first worksheet of an .xlsx file into a list of rows.
  static List<List<String>> parseWorkbook(Uint8List bytes) {
    return ProductExcelService.parseWorkbook(bytes);
  }
}
