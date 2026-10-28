import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin_app/shared/widgets/admin_excel_button.dart';

/// زر التصدير المشترك بين أدلة السجلات: يعطّل نفسه حين لا توجد صفوف،
/// ويبدّل تسميته وحالته أثناء العمل حين يمرّر الدليل مؤشر انشغال.
/// رسمه هو زرار Excel واحد، فيبقى شكله كشكل زرار صفحة المدفوعات.
class AdminExportButton extends StatelessWidget {
  const AdminExportButton({
    super.key,
    required this.label,
    required this.busyLabel,
    required this.onPressed,
    this.busy,
    this.enabled = true,
  });

  final String label;
  final String busyLabel;
  final VoidCallback onPressed;

  /// مؤشر انشغال الدليل؛ عند غيابه يبقى الزر ساكنًا بتسمية واحدة.
  final ValueListenable<bool>? busy;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final listenable = busy;
    if (listenable == null) {
      return AdminExcelButton(
        action: ExcelAction.export,
        label: label,
        onPressed: enabled ? onPressed : null,
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, isBusy, _) => AdminExcelButton(
        action: ExcelAction.export,
        label: isBusy ? busyLabel : label,
        busy: isBusy,
        onPressed: enabled && !isBusy ? onPressed : null,
      ),
    );
  }
}
