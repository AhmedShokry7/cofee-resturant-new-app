import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_amount_field.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_date_field.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_form_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_labels.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:flutter/material.dart';

/// قيم تسوية على قسيمة: نوع ومبلغ وسبب وتاريخ سريان، مطابقة لـ `correction`.
class HrCorrectionAdjustmentDraft {
  const HrCorrectionAdjustmentDraft({
    required this.kind,
    required this.amount,
    required this.reason,
    this.effectiveDate,
  });

  final String kind;
  final double amount;
  final String reason;
  final DateTime? effectiveDate;
}

/// الأنواع التي تقبلها دالة التصحيح في القاعدة؛ ما عداها يُرفض `22023`.
const List<String> _correctionKinds = <String>[
  'allowance',
  'bonus',
  'commission',
  'overtime',
  'deduction',
];

/// حوار تصحيح قسيمة: يُنشئ تسوية جديدة معتمدة، ولا يمسّ القسيمة نفسها.
///
/// القسيمة المعتمدة لقطة محفوظة، لذا يبقى السطر التوضيحي (`hrStatementImmutable`)
/// ظاهرًا: المدير يضيف أثرًا ماليًا للدورة القادمة، لا يعيد كتابة ما استلمه الموظف.
Future<HrCorrectionAdjustmentDraft?> showHrStatementCorrectionDialog(
  BuildContext context, {
  required String statementId,
  required String staffName,
}) => showDialog<HrCorrectionAdjustmentDraft>(
  context: context,
  builder: (dialogContext) =>
      _HrCorrectionDialog(statementId: statementId, staffName: staffName),
);

class _HrCorrectionDialog extends StatefulWidget {
  const _HrCorrectionDialog({
    required this.statementId,
    required this.staffName,
  });

  final String statementId;
  final String staffName;

  @override
  State<_HrCorrectionDialog> createState() => _HrCorrectionDialogState();
}

class _HrCorrectionDialogState extends State<_HrCorrectionDialog> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  String _kind = _correctionKinds.first;
  DateTime? _effective;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(normalizeDigits(_amount.text.trim()));
    final reason = _reason.text.trim();
    if (amount == null || amount <= 0) {
      setState(() => _error = S.hrAmountMustBePositive);
      return;
    }
    if (reason.isEmpty) {
      setState(() => _error = S.hrCorrectionReasonRequired);
      return;
    }
    Navigator.of(context).pop(
      HrCorrectionAdjustmentDraft(
        kind: _kind,
        amount: amount,
        reason: reason,
        effectiveDate: _effective,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HrFormDialog(
      title: S.hrPayrollCorrectionTitle,
      error: _error,
      subtitle: widget.staffName,
      saveLabel: S.hrBtnStatementCorrection,
      saveKey: const Key('hr-correction-save'),
      onSave: _submit,
      children: [
        // التصحيح لا يعدّل القسيمة، بل يضيف تسوية معتمدة للدورة القادمة.
        Text(
          S.hrStatementImmutable,
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size10_5,
            height: AppTextHeights.line1_5,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        hrDropdownField<String>(
          context,
          label: S.hrAdjustmentKind,
          value: _kind,
          items: [
            for (final kind in _correctionKinds)
              DropdownMenuItem(value: kind, child: Text(hrKindLabel(kind))),
          ],
          onChanged: (value) => setState(() => _kind = value ?? _kind),
        ),
        const SizedBox(height: AppSpacing.md),
        HrAmountField(
          label: S.amount,
          hint: S.hrAmountHint,
          controller: _amount,
          required: true,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _reason,
          minLines: 3,
          maxLines: 5,
          style: TextStyle(fontSize: AppFontSizes.size12_5),
          decoration: adminDialogFieldDecoration(
            context,
            label: S.hrReasonLabel,
            hint: S.hrReasonHint,
            required: true,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        HrDateField(
          label: S.hrCompensationEffectiveFrom,
          value: _effective,
          onChanged: (value) => setState(() => _effective = value),
        ),
      ],
    );
  }
}
