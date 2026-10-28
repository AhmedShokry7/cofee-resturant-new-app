import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/shared/widgets/excel_icon.dart';

/// Offers the template-or-file choice that starts any Excel import.
///
/// The same dialog is shown by the products and the categories pages, so the
/// admin always meets one choice before a workbook is picked or downloaded.
class AdminImportExcelDialog extends StatelessWidget {
  const AdminImportExcelDialog({
    super.key,
    required this.onPickFile,
    required this.onDownloadSample,
  });

  final VoidCallback onPickFile;
  final VoidCallback onDownloadSample;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(S.importExcel),
    content: Text(S.downloadSampleFileHint),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(S.cancel),
      ),
      OutlinedButton.icon(
        onPressed: onDownloadSample,
        icon: const ExcelIcon(size: 18),
        label: Text(S.downloadSampleFile),
      ),
      FilledButton.icon(
        onPressed: onPickFile,
        icon: const ExcelIcon(size: 18),
        label: Text(S.uploadFromDevice),
      ),
    ],
  );
}
