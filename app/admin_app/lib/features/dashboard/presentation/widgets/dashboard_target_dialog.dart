import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
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
  /// سقف `admin_set_revenue_target`؛ تجاوزها يطبع استثناء القاعدة الخام بدل
  /// رسالة تُفهم.
  static const double _maxTarget = 100000000;

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

  /// الصفر والسالب يرفضان هنا، والسقف ترفضه القاعدة بـ `22003`: الحقل يطلب
  /// هدفًا حقيقيًا، وصفره لا يعني «لا هدف» بل هدفًا معدومًا.
  ///
  /// الحقل يقرأ الأرقام العربية مثل اللاتينية، لأن اللوحة تعرض كل مقاديرها
  /// بالأرقام العربية ومن ينسخ رقمًا منها يلصقه هنا.
  Future<void> _submit() async {
    final value = double.tryParse(
      normalizeDigits(_amount.text).trim().replaceAll(',', ''),
    );
    if (value == null || value <= 0) {
      setState(() => _error = S.dashboardTargetInvalid);
      return;
    }
    if (value > _maxTarget) {
      setState(() => _error = S.dashboardTargetTooLarge);
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
