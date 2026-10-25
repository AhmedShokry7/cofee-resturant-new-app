import 'package:file_picker/file_picker.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/catalog/data/category_excel_mapper.dart';
import 'package:admin_app/features/catalog/data/category_excel_service.dart';
import 'package:admin_app/features/catalog/data/models/admin_category.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_category_cubit.dart';

/// The outcome of one Excel import of categories.
class CategoryImportReport {
  const CategoryImportReport({
    required this.rowCount,
    required this.created,
    required this.updated,
    required this.errors,
  });

  final int rowCount;
  final int created;
  final int updated;
  final List<CategoryImportRowError> errors;
}

/// Reads and writes the categories of the dashboard from and to Excel files.
///
/// The controller owns the whole workflow, so the page only asks for a run
/// and shows the report; the progress of a run is handed to [onProgress].
class CategoryExcelController {
  CategoryExcelController({required this.cubit, required this.onProgress});

  /// The cubit of the categories every save goes through.
  final AdminCategoryCubit cubit;

  /// Called with the progress of the running job, from 0 to 1.
  final void Function(double? progress) onProgress;

  /// True while an import is running, so the page may lock its buttons.
  bool importing = false;

  /// True while an export is running.
  bool exporting = false;

  /// The failure of the last run, in plain words, when there was one.
  String? lastError;

  /// Turns a failure of one row into a sentence the admin understands.
  static String explainSaveError(Object error) {
    final message = error.toString();
    if (message.contains('duplicate') || message.contains('unique')) {
      return 'Duplicate category name';
    }
    if (message.contains('network') || message.contains('connection')) {
      return 'Network error';
    }
    if (message.contains('permission') || message.contains('unauthorized')) {
      return 'Permission denied';
    }
    return 'Database error';
  }

  /// Asks for a workbook, writes every row it holds and reloads the list.
  ///
  /// Returns null when the admin cancelled the picker or the file could not
  /// be read; the failure is then reported by [errorMessage].
  Future<CategoryImportReport?> importFile() async {
    if (importing) return null;
    importing = true;
    lastError = null;
    onProgress(0.0);
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: S.importExcel,
    // ignore: deprecated_member_use
        type: FileType.custom,
    // ignore: deprecated_member_use
        allowedExtensions: const <String>['xlsx'],
      );
      if (file == null) return null;

      onProgress(0.1);
      final rows = CategoryExcelService.parseWorkbook(await file.readAsBytes());

      onProgress(0.3);
      final result = CategoryExcelMapper.fromRows(
        rows,
        existingById: {for (final c in cubit.state.categories) c.id: c},
      );

      onProgress(0.5);
      var created = 0;
      var updated = 0;
      final allErrors = List<CategoryImportRowError>.from(result.errors);
      final total = result.categories.length;

      for (var i = 0; i < total; i++) {
        final category = result.categories[i];
        try {
          await cubit.createCategory(
            nameAr: category.nameAr,
            nameEn: category.nameEn,
            descriptionAr: category.descriptionAr,
            descriptionEn: category.descriptionEn,
          );
          created++;
        } catch (error) {
          allErrors.add(
            CategoryImportRowError(
              rowNumber: i + 1,
              categoryName: category.nameAr.isEmpty
                  ? category.nameEn
                  : category.nameAr,
              reason: explainSaveError(error),
            ),
          );
        }
        if (total > 0) onProgress(0.5 + (0.4 * (i + 1) / total));
      }

      onProgress(0.95);
      await cubit.load();
      onProgress(1.0);
      await Future.delayed(const Duration(milliseconds: 300));

      return CategoryImportReport(
        rowCount: result.rowCount,
        created: created,
        updated: updated,
        errors: allErrors,
      );
    } catch (error) {
      lastError = '${S.invalidExcelFile}: $error';
      return null;
    } finally {
      importing = false;
      onProgress(null);
    }
  }

  /// Writes the given categories to a workbook and asks where to save it.
  ///
  /// Returns false when the admin cancelled the picker.
  Future<bool> exportFile(Iterable<AdminCategory> categories) async {
    if (exporting) return false;
    exporting = true;
    onProgress(0.0);
    try {
      onProgress(0.3);
      final bytes = CategoryExcelService.buildWorkbook(
        CategoryExcelMapper.toRows(categories),
      );
      onProgress(0.7);
      final uri = await FilePicker.saveFile(
        dialogTitle: S.exportExcel,
        fileName:
            'categories-${DateTime.now().toIso8601String().split('T').first}.xlsx',
        bytes: bytes,
    // ignore: deprecated_member_use
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    // ignore: deprecated_member_use
        type: FileType.custom,
    // ignore: deprecated_member_use
        allowedExtensions: const <String>['xlsx'],
      );
      if (uri == null) return false;
      onProgress(1.0);
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    } finally {
      exporting = false;
      onProgress(null);
    }
  }

  /// Asks where to save the empty workbook the admin may fill in.
  Future<bool> downloadSample() async {
    final sampleRow = <String>[
      'CAT-001',
      'Coffee',
      'Coffee',
      'Description in English',
      'Description in English',
      'true',
    ];
    final bytes = CategoryExcelService.buildWorkbook([
      CategoryExcelService.headers,
      sampleRow,
    ]);
    final uri = await FilePicker.saveFile(
      dialogTitle: S.downloadSampleFile,
      fileName: 'categories-sample.xlsx',
      bytes: bytes,
    // ignore: deprecated_member_use
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    // ignore: deprecated_member_use
      type: FileType.custom,
    // ignore: deprecated_member_use
      allowedExtensions: const <String>['xlsx'],
    );
    return uri != null;
  }
}
