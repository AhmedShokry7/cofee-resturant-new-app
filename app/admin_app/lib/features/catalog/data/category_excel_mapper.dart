import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/catalog/data/category_excel_service.dart';
import 'package:admin_app/features/catalog/data/models/admin_category.dart';

/// A single row that failed to import, with the reason.
class CategoryImportRowError {
  const CategoryImportRowError({
    required this.rowNumber,
    required this.reason,
    this.categoryName,
  });

  final int rowNumber;
  final String reason;
  final String? categoryName;
}

/// The categories read from a workbook, and the rows that were left out.
class CategoryExcelImport {
  const CategoryExcelImport({
    required this.categories,
    required this.invalidRows,
    required this.rowCount,
    this.errors = const <CategoryImportRowError>[],
  });

  final List<AdminCategory> categories;
  final int invalidRows;
  final int rowCount;
  final List<CategoryImportRowError> errors;
}

/// Turns the categories into workbook rows and back.
class CategoryExcelMapper {
  CategoryExcelMapper._();

  /// The workbook of the categories, with the header row on top.
  static List<List<String>> toRows(Iterable<AdminCategory> categories) {
    final rows = <List<String>>[CategoryExcelService.headers];
    for (final category in categories) {
      rows.add(<String>[
        category.id,
        category.nameAr,
        category.nameEn,
        category.descriptionAr ?? '',
        category.descriptionEn ?? '',
        category.isActive ? 'TRUE' : 'FALSE',
      ]);
    }
    return rows;
  }

  /// Reads the categories of a workbook.
  static CategoryExcelImport fromRows(
    List<List<String>> rows, {
    Map<String, AdminCategory> existingById = const <String, AdminCategory>{},
  }) {
    if (rows.isEmpty) {
      return const CategoryExcelImport(
        categories: <AdminCategory>[],
        invalidRows: 0,
        rowCount: 0,
      );
    }

    final headerIndex = <String, int>{};
    final header = rows.first;
    for (var index = 0; index < header.length; index++) {
      final name = _normalize(header[index]);
      if (name.isNotEmpty) headerIndex[name] = index;
    }

    for (final required in <String>['name (arabic)', 'name (english)']) {
      if (!headerIndex.containsKey(required)) {
        throw FormatException(S.missingExcelColumn(_label(required)));
      }
    }

    final categories = <AdminCategory>[];
    final errors = <CategoryImportRowError>[];
    var invalidRows = 0;
    var rowCount = 0;

    for (final row in rows.skip(1)) {
      if (row.every((value) => value.trim().isEmpty)) continue;
      rowCount++;

      final nameAr = (_value(row, headerIndex, 'name (arabic)') ?? '').trim();
      final nameEn = (_value(row, headerIndex, 'name (english)') ?? '').trim();

      final reasons = <String>[];
      if (nameAr.isEmpty) {
        reasons.add(S.excelArabicNameRequired);
      }
      if (nameEn.isEmpty) {
        reasons.add(S.excelEnglishNameRequired);
      }

      if (reasons.isNotEmpty) {
        invalidRows++;
        errors.add(
          CategoryImportRowError(
            rowNumber: rowCount,
            categoryName: nameAr.isEmpty ? null : nameAr,
            reason: reasons.join(', '),
          ),
        );
        continue;
      }

      final rawId = (_value(row, headerIndex, 'id') ?? '').trim();
      final descriptionAr = _value(row, headerIndex, 'description (arabic)');
      final descriptionEn = _value(row, headerIndex, 'description (english)');
      final isActiveText = _value(row, headerIndex, 'active');

      final existing = rawId.isEmpty ? null : existingById[rawId];
      final category =
          existing ??
          AdminCategory(
            id: rawId.isEmpty
                ? 'draft-${DateTime.now().microsecondsSinceEpoch}-$rowCount'
                : rawId,
            nameAr: nameAr,
            nameEn: nameEn,
            descriptionAr: descriptionAr?.trim().isEmpty == true
                ? null
                : descriptionAr?.trim(),
            descriptionEn: descriptionEn?.trim().isEmpty == true
                ? null
                : descriptionEn?.trim(),
            isActive: _bool(isActiveText ?? '', fallback: true),
          );

      categories.add(category);
    }

    return CategoryExcelImport(
      categories: categories,
      invalidRows: invalidRows,
      rowCount: rowCount,
      errors: errors,
    );
  }

  static String? _value(
    List<String> row,
    Map<String, int> headerIndex,
    String header,
  ) {
    final index = headerIndex[_normalize(header)];
    if (index == null || index >= row.length) return null;
    return row[index];
  }

  static bool _bool(String value, {required bool fallback}) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'y':
      case 'نعم':
      case 'مفعل':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'n':
      case 'لا':
      case 'معطل':
        return false;
      default:
        return fallback;
    }
  }

  static String _normalize(String value) => value.trim().toLowerCase();

  static String _label(String header) => CategoryExcelService.headers
      .firstWhere((entry) => _normalize(entry) == header, orElse: () => header);
}
