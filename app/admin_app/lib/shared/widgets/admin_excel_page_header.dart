import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/shared/widgets/admin_excel_button.dart';
import 'package:admin_app/shared/widgets/admin_import_excel_dialog.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

/// The header of a page whose records travel in and out through Excel.
///
/// Products and categories share this one control: the upload button offers
/// the template-or-file choice, every action is locked while a job runs, and
/// each page supplies its own labels, handlers and bulk-selection footer.
class AdminExcelPageHeader extends StatelessWidget {
  const AdminExcelPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.addActionLabel,
    required this.onAdd,
    this.onPickFile,
    this.onDownloadSample,
    this.onExport,
    this.importProgress,
    this.exportProgress,
    this.footer,
  });

  final String title;
  final String subtitle;
  final String addActionLabel;
  final VoidCallback onAdd;

  /// Starts the import of the page, after the admin chose the file.
  final VoidCallback? onPickFile;

  /// Writes the empty workbook whose columns the page reads back.
  final VoidCallback? onDownloadSample;

  /// Writes the records of the page to a workbook.
  final VoidCallback? onExport;

  final double? importProgress;
  final double? exportProgress;

  /// The bulk selection row of the page, under the actions.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final progress = importProgress ?? exportProgress;
    final busy = progress != null;

    return AdminPageHeader(
      title: title,
      subtitle: subtitle,
      progress: progress,
      progressLabel: importProgress != null ? S.importing : S.exporting,
      actions: [
        if (onPickFile != null || onDownloadSample != null)
          AdminExcelButton(
            action: ExcelAction.import,
            onPressed: busy ? null : () => _showImportDialog(context),
          ),
        if (onExport != null)
          AdminExcelButton(
            action: ExcelAction.export,
            onPressed: busy ? null : onExport,
          ),
        CustomBtn(
          text: addActionLabel,
          onPressed: busy ? null : onAdd,
          leadingIcon: const Icon(AppIcons.add01, size: 18),
          height: 42,
          borderRadius: AppRadius.pill,
          backgroundColor: AppColor.primaryColor,
          textColor: AppColor.whiteColor,
        ),
      ],
      footer: footer,
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AdminImportExcelDialog(
        onPickFile: () {
          Navigator.of(context).pop();
          onPickFile?.call();
        },
        onDownloadSample: () {
          Navigator.of(context).pop();
          onDownloadSample?.call();
        },
      ),
    );
  }
}
