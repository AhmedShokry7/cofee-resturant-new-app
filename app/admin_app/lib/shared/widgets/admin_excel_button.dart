import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';
import 'package:admin_app/shared/widgets/excel_icon.dart';

/// Which way the workbook moves.
enum ExcelAction {
  /// A workbook comes in.
  import,

  /// A workbook goes out.
  export,
}

/// The one Excel action button in the dashboard: the directory chip of the
/// payments page, with the workbook mark and a single word on it.
///
/// Every page that reads or writes a workbook uses this button, so the
/// import and the export never meet two shapes. A page may keep its own word
/// through [label] while the directory toolbars keep their busy state.
class AdminExcelButton extends StatelessWidget {
  const AdminExcelButton({
    super.key,
    required this.action,
    this.label,
    this.busy = false,
    this.onPressed,
  });

  final ExcelAction action;

  /// The word of the page, when it already names the job its own way.
  final String? label;

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AdminToolbarButton(
    label:
        label ?? (action == ExcelAction.export ? S.excelExport : S.excelImport),
    iconWidget: const ExcelIcon(size: 16),
    busy: busy,
    onPressed: onPressed,
  );
}
