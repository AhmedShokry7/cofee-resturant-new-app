import 'package:file_picker/file_picker.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/features/catalog/data/product_excel_mapper.dart';
import 'package:admin_app/core/services/product_excel_service.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_product_cubit.dart';

/// The outcome of one Excel import of products.
class ProductImportReport {
  const ProductImportReport({
    required this.rowCount,
    required this.created,
    required this.updated,
    required this.errors,
  });

  final int rowCount;
  final int created;
  final int updated;
  final List<ImportRowError> errors;
}

/// Reads and writes the products of the dashboard from and to Excel files.
///
/// The controller owns the whole workflow, so the page only asks for a run
/// and shows the report; the progress of a run is handed to [onProgress].
class ProductExcelController {
  ProductExcelController({required this.cubit, required this.onProgress});

  /// The cubit of the products every save goes through.
  final AdminProductCubit cubit;

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
      return S.duplicateSkuOrSlug;
    }
    if (message.contains('network') || message.contains('connection')) {
      return S.networkError;
    }
    if (message.contains('permission') || message.contains('unauthorized')) {
      return S.permissionDenied;
    }
    return S.databaseError;
  }

  /// Asks for a workbook, writes every row it holds and reloads the list.
  Future<ProductImportReport?> importFile() async {
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
      final rows = ProductExcelService.parseWorkbook(await file.readAsBytes());
      final snapshot = await cubit.loadCatalogSnapshot();
      final existing = <String, AdminProduct>{
        for (final product in snapshot.products)
          if (!product.isDraft) product.id: product,
      };

      onProgress(0.2);
      final result = ProductExcelMapper.fromRows(
        rows,
        snapshot.categories,
        existingById: existing,
      );

      onProgress(0.3);
      var created = 0;
      var updated = 0;
      final allErrors = List<ImportRowError>.from(result.errors);
      final total = result.products.length;

      for (var i = 0; i < total; i++) {
        final product = result.products[i];
        final isNew = product.isDraft;
        try {
          await cubit.saveProduct(product);
          if (isNew) {
            created++;
          } else {
            updated++;
          }
        } catch (error) {
          allErrors.add(
            ImportRowError(
              rowNumber: i + 1,
              productName: product.nameAr.isEmpty
                  ? product.nameEn
                  : product.nameAr,
              reason: explainSaveError(error),
            ),
          );
        }
        if (total > 0) onProgress(0.3 + (0.6 * (i + 1) / total));
      }

      onProgress(0.95);
      await cubit.load(search: cubit.state.search);
      onProgress(1.0);
      await Future.delayed(const Duration(milliseconds: 300));

      return ProductImportReport(
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

  /// Writes every product that matches the search to a workbook.
  ///
  /// Returns false when the admin cancelled the picker.
  Future<bool> exportFile() async {
    if (exporting) return false;
    exporting = true;
    onProgress(0.0);
    try {
      onProgress(0.2);
      final snapshot = await cubit.loadCatalogSnapshot(
        search: cubit.state.search,
      );
      onProgress(0.5);
      final bytes = ProductExcelService.buildWorkbook(
        ProductExcelMapper.toRows(snapshot.products),
      );
      onProgress(0.8);
      final uri = await FilePicker.saveFile(
        dialogTitle: S.exportExcel,
        fileName:
            'products-${DateTime.now().toIso8601String().split('T').first}.xlsx',
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
    } catch (error) {
      lastError = '${S.exportExcel}: $error';
      return false;
    } finally {
      exporting = false;
      onProgress(null);
    }
  }

  /// Asks where to save the empty workbook the admin may fill in.
  Future<bool> downloadSample() async {
    final sampleRow = List<String>.filled(
      ProductExcelService.headers.length,
      '',
    );
    sampleRow[0] = 'PROD-001';
    sampleRow[1] = 'COFFEE-001';
    sampleRow[2] = 'قهوة عربية';
    sampleRow[3] = 'Arabic Coffee';
    sampleRow[4] = 'وصف بالعربية';
    sampleRow[5] = 'Description in English';
    sampleRow[6] = 'arabic-coffee';
    sampleRow[7] = 'Coffee';
    sampleRow[8] = '25.00';
    sampleRow[9] = '30.00';
    sampleRow[10] = '10';
    sampleRow[13] = 'true';
    sampleRow[14] = 'false';
    sampleRow[15] = '5';
    sampleRow[16] = '120';
    sampleRow[17] = 'milk,nuts';

    final bytes = ProductExcelService.buildWorkbook([
      ProductExcelService.headers,
      sampleRow,
    ]);
    final uri = await FilePicker.saveFile(
      dialogTitle: S.downloadSampleFile,
      fileName: 'products-sample.xlsx',
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
