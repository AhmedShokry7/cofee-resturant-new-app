import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

/// زر التصدير المشترك بين أدلة السجلات: يعطّل نفسه حين لا توجد صفوف،
/// ويبدّل تسميته وحالته أثناء العمل حين يمرّر الدليل مؤشر انشغال.
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
      return AdminToolbarButton(
        label: label,
        icon: AppIcons.download02,
        onPressed: enabled ? onPressed : null,
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, isBusy, _) => AdminToolbarButton(
        label: isBusy ? busyLabel : label,
        icon: AppIcons.download02,
        busy: isBusy,
        onPressed: enabled && !isBusy ? onPressed : null,
      ),
    );
  }
}
