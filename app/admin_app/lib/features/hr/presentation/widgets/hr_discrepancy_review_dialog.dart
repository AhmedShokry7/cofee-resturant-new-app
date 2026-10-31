import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_discrepancy.dart';
import 'package:admin_app/features/hr/presentation/models/hr_discrepancy_action.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_amount_field.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_form_dialog.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:flutter/material.dart';

/// قرار على فرق صندوق: توضيح أو تسوية أو إثبات أو رفض أو خصم أو إغلاق.
///
/// الفرق نفسه ليس اتهامًا؛ النسب قرار إداري، والخصم لا ينفذ هنا بل يُقترح ليُراجَع
/// كقيد مستقلّ. لذلك يظهر حقل الموظف والمبلغ للخصم وحده، ويُمنع حين تعطّل الخصم
/// في السياسة أو تجاوز السقف الذي يراه المدير.
Future<HrDiscrepancyReviewDraft?> showHrDiscrepancyReviewDialog(
  BuildContext context, {
  required HrDiscrepancy discrepancy,
  required List<HrPersonOption>? people,
  required bool deductionsAllowed,
  required double capPercent,
}) => showDialog<HrDiscrepancyReviewDraft>(
  context: context,
  builder: (dialogContext) => _HrDiscrepancyReviewDialog(
    discrepancy: discrepancy,
    people: people,
    deductionsAllowed: deductionsAllowed,
    capPercent: capPercent,
  ),
);

/// قيم المراجعة المرسلة لـ `HrDiscrepanciesCubit.review`.
class HrDiscrepancyReviewDraft {
  const HrDiscrepancyReviewDraft({
    required this.action,
    required this.note,
    required this.evidence,
    this.attributedStaffId,
    this.deductionAmount,
  });

  final HrDiscrepancyAction action;
  final String note;
  final String evidence;
  final String? attributedStaffId;
  final double? deductionAmount;
}

class _HrDiscrepancyReviewDialog extends StatefulWidget {
  const _HrDiscrepancyReviewDialog({
    required this.discrepancy,
    required this.people,
    required this.deductionsAllowed,
    required this.capPercent,
  });

  final HrDiscrepancy discrepancy;
  final List<HrPersonOption>? people;
  final bool deductionsAllowed;
  final double capPercent;

  @override
  State<_HrDiscrepancyReviewDialog> createState() =>
      _HrDiscrepancyReviewDialogState();
}

class _HrDiscrepancyReviewDialogState
    extends State<_HrDiscrepancyReviewDialog> {
  final TextEditingController _note = TextEditingController();
  final TextEditingController _evidence = TextEditingController();
  final TextEditingController _deduction = TextEditingController();
  HrDiscrepancyAction _action = HrDiscrepancyAction.explain;
  String? _attributedId;
  String? _error;

  bool get _isDeduct => _action == HrDiscrepancyAction.deduct;

  /// السقف الظاهر للمدير: نسبة من مبلغ الفرق، لا تقدير من الشاشة.
  double get _cap => widget.discrepancy.amount * widget.capPercent / 100;

  @override
  void initState() {
    super.initState();
    _attributedId = widget.discrepancy.attributedStaffId;
  }

  @override
  void dispose() {
    _note.dispose();
    _evidence.dispose();
    _deduction.dispose();
    super.dispose();
  }

  /// الأربعة التي ترفض القاعدة فراغ ملاحظتها، ولكلٍّ نصّ رفضها.
  String? get _missingNoteLabel => switch (_action) {
    HrDiscrepancyAction.explain => S.hrExplanationNeedsNote,
    HrDiscrepancyAction.reject => S.hrRejectionNeedsNote,
    HrDiscrepancyAction.deduct => S.hrDeductionNeedsNote,
    HrDiscrepancyAction.confirm => S.hrReasonMissing,
    _ => null,
  };

  void _submit() {
    final note = _note.text.trim();
    if (_missingNoteLabel != null && note.isEmpty) {
      setState(() => _error = _missingNoteLabel);
      return;
    }
    double? deduction;
    String? attributed;
    if (_isDeduct) {
      if (!widget.deductionsAllowed) {
        setState(() => _error = S.hrDeductionsDisabled);
        return;
      }
      attributed = _attributedId;
      if (attributed == null) {
        setState(() => _error = S.hrConfirmNeedsEmployee);
        return;
      }
      final parsed = parseLocalizedNumber(_deduction.text);
      if (parsed == null || parsed <= 0 || parsed > _cap) {
        setState(() => _error = S.hrDeductionOutOfRange);
        return;
      }
      deduction = parsed;
    }
    Navigator.of(context).pop(
      HrDiscrepancyReviewDraft(
        action: _action,
        note: note,
        evidence: _evidence.text.trim(),
        attributedStaffId: attributed,
        deductionAmount: deduction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HrFormDialog(
      title: S.hrDiscrepancyTitle,
      error: _error,
      subtitle: S.hrDiscrepancyAttributionHint,
      saveLabel: S.hrBtnReview,
      saveKey: const Key('hr-discrepancy-save'),
      onSave: _submit,
      children: [
        hrDropdownField<HrDiscrepancyAction>(
          context,
          label: S.hrColType,
          value: _action,
          items: [
            for (final action in HrDiscrepancyAction.values)
              DropdownMenuItem(value: action, child: Text(action.label)),
          ],
          onChanged: (value) => setState(() => _action = value ?? _action),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _note,
          minLines: 3,
          maxLines: 5,
          style: const TextStyle(fontSize: AppFontSizes.size12_5),
          decoration: adminDialogFieldDecoration(
            context,
            label: S.hrFieldNote,
            hint: S.hrReasonHint,
            required: _missingNoteLabel != null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _evidence,
          style: const TextStyle(fontSize: AppFontSizes.size12_5),
          decoration: adminDialogFieldDecoration(
            context,
            label: S.hrFieldEvidence,
            hint: S.hrDocumentHint,
          ),
        ),
        if (_isDeduct) _deductFields(context, theme),
      ],
    );
  }

  /// حقول الخصم وحدها: الموظف المنسوب إليه والمبلغ المقترح مع سقفه الظاهر.
  Widget _deductFields(BuildContext context, ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: AppSpacing.md),
      hrEmployeeField(
        context,
        people: widget.people,
        value: _attributedId,
        label: S.hrDiscrepancyAttributed,
        onChanged: (value) => setState(() => _attributedId = value),
      ),
      const SizedBox(height: AppSpacing.md),
      HrAmountField(
        label: S.hrDiscrepancyDeduction,
        hint: S.hrAmountHint,
        controller: _deduction,
        required: true,
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(
            child: Text(
              S.hrPolicyDeductionCap,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size10_5,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AdminMoneyText(value: _cap, fontSize: AppFontSizes.size11_5),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        widget.deductionsAllowed
            ? S.hrConfirmBeforeDeduct
            : S.hrDeductionsDisabled,
        style: TextStyle(
          color: adminBodyColor(theme),
          fontSize: AppFontSizes.size10_5,
          height: AppTextHeights.line1_5,
        ),
      ),
    ],
  );
}
