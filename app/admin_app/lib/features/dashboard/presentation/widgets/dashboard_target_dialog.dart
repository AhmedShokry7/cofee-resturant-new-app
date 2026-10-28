import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_target_dialog_view.dart';

/// يفتح حوار هدف الشهر: مبلغ واحد يُكتب، ثم يُقفل أو يبقى مع رفضه.
///
/// الملف يحمل القرار لا الرسم: منادي الكتابة يحرس متى يُغلق الحوار، والشاشة في
/// ملفها تعرف الحقل والزرّين فقط.
Future<void> showDashboardTargetDialog({
  required BuildContext context,
  required double? current,
  required Future<String?> Function(double) onSubmit,
}) => showDialog<void>(
  context: context,
  builder: (context) =>
      DashboardTargetDialog(current: current, onSubmit: onSubmit),
);

/// حقل الهدف وزرّاه.
///
/// `onSubmit` تكتب في القاعدة وترجع نصّ رفضها أو `null` عند النجاح، فلا يُغلق
/// الحوار ولا يُعرض نجاحه إلا حين تكون القاعدة هي التي كتبت الرقم.
class DashboardTargetDialog extends StatefulWidget {
  const DashboardTargetDialog({
    super.key,
    required this.current,
    required this.onSubmit,
  });

  /// المبلغ المحفوظ حاليًا، ليُطبع في الحقل لا أن يخمّنه الأدمن.
  final double? current;

  /// كتابة الهدف: ترجع رسالة الرفض أو `null` حين نجحت القاعدة.
  final Future<String?> Function(double) onSubmit;

  @override
  State<DashboardTargetDialog> createState() => _DashboardTargetDialogState();
}

class _DashboardTargetDialogState extends State<DashboardTargetDialog> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.current?.toStringAsFixed(2) ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// الصفر والسالب مرفوضان كما ترفضهما القاعدة (`22003`)، فزرٌّ لا يكتب شيئًا.
  Future<void> _submit() async {
    final value = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (value == null || value <= 0) {
      setState(() => _error = S.dashboardTargetInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final failure = await widget.onSubmit(value);
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DashboardTargetDialogView(
      title: widget.current == null
          ? S.dashboardTargetSet
          : S.dashboardTargetEdit,
      subtitle: S.dashboardTargetEmptyHint,
      controller: _amount,
      saving: _saving,
      error: _error,
      onSubmit: _submit,
      onClose: () => Navigator.of(context).pop(),
    );
  }
}
