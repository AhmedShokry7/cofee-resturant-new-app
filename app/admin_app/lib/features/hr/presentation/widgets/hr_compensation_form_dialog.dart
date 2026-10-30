import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_amount_field.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_date_field.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_form_dialog.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:flutter/material.dart';

/// قيم تركيبة الأجر، بنفس أعمدة `setCompensation` في الـ Cubit.
class HrCompensationDraft {
  const HrCompensationDraft({
    required this.staffId,
    required this.basicSalary,
    this.housingAllowance = 0,
    this.transportAllowance = 0,
    this.otherAllowance = 0,
    this.effectiveFrom,
    this.note,
  });

  final String staffId;
  final double basicSalary;
  final double housingAllowance;
  final double transportAllowance;
  final double otherAllowance;
  final DateTime? effectiveFrom;
  final String? note;
}

/// حوار تركيبة الأجر: شريط ساري من تاريخ، ولا يُكتب الأجر في القسيمة نفسها.
///
/// يرجع المدير هنا عن أجر سابق بتاريخ قديم ترفضه القاعدة (`hrCompensationBackdate`)،
/// فالتوضيح ظاهر: النطاق يرجع بالتاريخ لا بمحرّر الرقم في القسيمة.
Future<HrCompensationDraft?> showHrCompensationFormDialog(
  BuildContext context, {
  required List<HrPersonOption>? people,
}) => showDialog<HrCompensationDraft>(
  context: context,
  builder: (dialogContext) => _HrCompensationDialog(people: people),
);

class _HrCompensationDialog extends StatefulWidget {
  const _HrCompensationDialog({required this.people});

  final List<HrPersonOption>? people;

  @override
  State<_HrCompensationDialog> createState() => _HrCompensationDialogState();
}

class _HrCompensationDialogState extends State<_HrCompensationDialog> {
  final TextEditingController _basic = TextEditingController();
  final TextEditingController _housing = TextEditingController();
  final TextEditingController _transport = TextEditingController();
  final TextEditingController _other = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String? _staffId;
  DateTime? _effectiveFrom;
  String? _error;

  @override
  void initState() {
    super.initState();
    _staffId = hrFirstPersonId(widget.people);
  }

  @override
  void dispose() {
    _basic.dispose();
    _housing.dispose();
    _transport.dispose();
    _other.dispose();
    _note.dispose();
    super.dispose();
  }

  /// مبلغ اختياري الفراغُ فيه صفر؛ لا يُقرأ الحقل الفارغ رقمًا خطأ.
  double _optional(TextEditingController controller) =>
      double.tryParse(normalizeDigits(controller.text.trim())) ?? 0;

  void _submit() {
    final staffId = _staffId;
    if (staffId == null) {
      setState(() => _error = S.hrStaffMissing);
      return;
    }
    final basic = double.tryParse(normalizeDigits(_basic.text.trim()));
    if (basic == null || basic <= 0) {
      setState(() => _error = S.hrInvalidSalary);
      return;
    }
    for (final field in <TextEditingController>[_housing, _transport, _other]) {
      final value = double.tryParse(normalizeDigits(field.text.trim()));
      if (field.text.trim().isNotEmpty && (value == null || value < 0)) {
        setState(() => _error = S.hrNegativeAllowance);
        return;
      }
    }
    final note = _note.text.trim();
    Navigator.of(context).pop(
      HrCompensationDraft(
        staffId: staffId,
        basicSalary: basic,
        housingAllowance: _optional(_housing),
        transportAllowance: _optional(_transport),
        otherAllowance: _optional(_other),
        effectiveFrom: _effectiveFrom,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HrFormDialog(
      title: S.hrCompensationTitle,
      error: _error,
      saveLabel: S.hrBtnSetCompensation,
      saveKey: const Key('hr-compensation-save'),
      onSave: _submit,
      children: [
        // التاريخ القديم يرفضه النطاق، فالشريط يرجع بالسريان لا بالحقل.
        Text(
          S.hrCompensationBackdate,
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size10_5,
            height: AppTextHeights.line1_5,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        hrEmployeeField(
          context,
          people: widget.people,
          value: _staffId,
          onChanged: (value) => setState(() => _staffId = value),
        ),
        const SizedBox(height: AppSpacing.md),
        HrAmountField(
          label: S.hrFieldBasicPay,
          hint: S.hrAmountHint,
          controller: _basic,
          required: true,
        ),
        const SizedBox(height: AppSpacing.md),
        HrAmountField(
          label: S.hrCompensationHousing,
          hint: S.hrAmountHint,
          controller: _housing,
        ),
        const SizedBox(height: AppSpacing.md),
        HrAmountField(
          label: S.hrCompensationTransport,
          hint: S.hrAmountHint,
          controller: _transport,
        ),
        const SizedBox(height: AppSpacing.md),
        HrAmountField(
          label: S.hrCompensationOther,
          hint: S.hrAmountHint,
          controller: _other,
        ),
        const SizedBox(height: AppSpacing.md),
        HrDateField(
          label: S.hrCompensationEffectiveFrom,
          value: _effectiveFrom,
          onChanged: (value) => setState(() => _effectiveFrom = value),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _note,
          minLines: 3,
          maxLines: 5,
          style: TextStyle(fontSize: AppFontSizes.size12_5),
          decoration: adminDialogFieldDecoration(
            context,
            label: S.hrFieldNote,
            hint: S.hrReasonHint,
          ),
        ),
      ],
    );
  }
}
