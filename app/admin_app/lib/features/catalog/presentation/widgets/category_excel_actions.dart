import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_category_excel_controller.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_dialogs.dart';
import 'package:admin_app/shared/widgets/admin_feedback.dart';

/// Asks for a workbook, writes it and shows the report of the run.
Future<void> runCategoryImport(
  BuildContext context,
  CategoryExcelController excel,
) async {
  final report = await excel.importFile();
  if (!context.mounted) return;
  if (report == null) {
    final error = excel.lastError;
    if (error != null) showErrorSnackBar(context, error);
    return;
  }
  showDialog<void>(
    context: context,
    builder: (context) => CategoryImportReportDialog(
      rowCount: report.rowCount,
      created: report.created,
      updated: report.updated,
      errors: report.errors,
    ),
  );
}

/// Writes the given categories to a workbook, and reports the result.
Future<void> runCategoryExport(
  BuildContext context,
  CategoryExcelController excel,
  Iterable<AdminCategory> categories,
) async {
  final saved = await excel.exportFile(categories);
  if (!context.mounted) return;
  if (saved) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.exportSuccess)));
    return;
  }
  final error = excel.lastError;
  if (error != null) showErrorSnackBar(context, error);
}

/// Asks where to save the empty workbook of the categories.
Future<void> runCategorySampleDownload(
  BuildContext context,
  CategoryExcelController excel,
) async {
  final saved = await excel.downloadSample();
  if (!saved || !context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(S.exportSuccess)));
}
