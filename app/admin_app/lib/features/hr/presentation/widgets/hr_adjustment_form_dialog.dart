import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_amount_field.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_date_field.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_form_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_labels.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:flutter/material.dart';

/// تسوية مالية جديدة يكتبها المدير: موظف ونوع ومبلغ وسبب.
///
/// النوع `deduction` لا يخصم شيئًا الآن: السطر يبقى `pending` حتى يُعتمد ويدخل
/// لقطة رواتب، فالحوار يصرّح بذلك بدل أن يوعد المدير بنقص راتب لم يقع بعد.
Future<HrAdjustmentDraft?> showHrAdjustmentFormDialog(
  BuildContext context, {
  required List<HrPersonOption>? people,
}) => showDialog<HrAdjustmentDraft>(
  context: context,
  builder: (dialogContext) => _HrAdjustmentFormDialog(people: people),
);

/// قيم تسوية يرسلها المدير، مطابقة لـ `HrAdjustmentsCubit.create`.
class HrAdjustmentDraft {
  const HrAdjustmentDraft({
    required this.staffId,
    required this.kind,
    required this.amount,
    required this.reason,
    this.quantity,
    this.effectiveDate,
  });

  final String staffId;
  final String kind;
  final double amount;
  final double? quantity;
  final String reason;
  final DateTime? effectiveDate;
}

class _HrAdjustmentFormDialog extends StatefulWidget {
  const _HrAdjustmentFormDialog({required this.people});

  final List<HrPersonOption>? people;

  @override
  State<_HrAdjustmentFormDialog> createState() =>
      _HrAdjustmentFormDialogState();
}

class _HrAdjustmentFormDialogState extends State<_HrAdjustmentFormDialog> {
  // الأسلاك الخمسة التي تقبلها القاعدة في عمود `kind`.
  static const List<String> _kinds = <String>[
    'allowance',
    'bonus',
    'commission',
    'overtime',
    'deduction',
  ];

  final TextEditingController _amount = TextEditingController();
  final TextEditingController _quantity = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  String? _staffId;
  String _kind = _kinds.first;
  DateTime? _effective;
  String? _error;

  @override
  void initState() {
    super.initState();
    _staffId = hrFirstPersonId(widget.people);
  }

  @override
  void dispose() {
    _amount.dispose();
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = parseLocalizedNumber(_amount.text);
    final reason = _reason.text.trim();
    if (_staffId == null) {
      setState(() => _error = S.hrStaffMissing);
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = S.hrAdjustmentNotPositive);
      return;
    }
    if (reason.isEmpty) {
      setState(() => _error = S.hrAdjustmentNeedsReason);
      return;
    }
    // الكمية تظهر للوقت الإضافي وحده؛ إن كُتبت وجب أن تكون موجبة.
    double? quantity;
    if (_kind == 'overtime' && _quantity.text.trim().isNotEmpty) {
      final parsed = parseLocalizedNumber(_quantity.text);
      if (parsed == null || parsed <= 0) {
        setState(() => _error = S.hrInvalidQuantity);
        return;
      }
      quantity = parsed;
    }
    Navigator.of(context).pop(
      HrAdjustmentDraft(
        staffId: _staffId!,
        kind: _kind,
        amount: amount,
        quantity: quantity,
        reason: reason,
        effectiveDate: _effective,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HrFormDialog(
      title: S.hrAdjustmentTitle,
      error: _error,
      subtitle: _kind == 'deduction' ? S.hrDiscrepancyAttributionHint : null,
      saveLabel: S.hrBtnNewAdjustment,
      saveKey: const Key('hr-adjustment-save'),
      onSave: _submit,
      children: [
        hrEmployeeField(
          context,
          people: widget.people,
          value: _staffId,
          onChanged: (value) => setState(() => _staffId = value),
        ),
        const SizedBox(height: AppSpacing.md),
        hrDropdownField<String>(
          context,
          label: S.hrAdjustmentKind,
          value: _kind,
          items: [
            for (final wire in _kinds)
              DropdownMenuItem(value: wire, child: Text(hrKindLabel(wire))),
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
        if (_kind == 'overtime') ...[
          const SizedBox(height: AppSpacing.md),
          // لا وسم «كمية» في الألفاظ: الأقرب هو عدّ الساعات (hrColWorked).
          TextField(
            controller: _quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: AppFontSizes.size12_5),
            decoration: adminDialogFieldDecoration(
              context,
              label: S.hrColWorked,
              hint: S.hrAmountHint,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        HrDateField(
          label: S.hrAdjustmentEffective,
          value: _effective,
          onChanged: (value) => setState(() => _effective = value),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _reason,
          minLines: 3,
          maxLines: 5,
          style: const TextStyle(fontSize: AppFontSizes.size12_5),
          decoration: adminDialogFieldDecoration(
            context,
            label: S.hrReasonLabel,
            hint: S.hrReasonHint,
            required: true,
          ),
        ),
        if (_kind == 'deduction') ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            S.hrConfirmBeforeDeduct,
            style: TextStyle(
              color: adminBodyColor(Theme.of(context)),
              fontSize: AppFontSizes.size10_5,
              height: AppTextHeights.line1_5,
            ),
          ),
        ],
      ],
    );
  }
}
