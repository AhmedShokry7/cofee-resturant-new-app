import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_form_dialog.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:flutter/material.dart';

/// قيم توليد دورة: سنة وشهر وملاحظة اختيارية، بنفس أعمدة `generate` في الـ Cubit.
class HrGenerateDraft {
  const HrGenerateDraft({
    required this.periodYear,
    required this.periodMonth,
    this.note,
  });

  final int periodYear;
  final int periodMonth;
  final String? note;
}

/// حوار احتساب الدورة: لا يُحتسب إلا بعد أن يقرأ المدير أن الدورة لقطة لا تُعدَّل.
///
/// السطر التوضيحي (`hrGeneratePayrollHint`) ضروري هنا: الدورة ما إن تُحسب حتى
/// تصير صورة محفوظة، فلا يظن المدير أنه يعدّل قسيمة حية حين يضغط الزر.
Future<HrGenerateDraft?> showHrGeneratePayrollDialog(
  BuildContext context, {
  int? year,
  int? month,
}) => showDialog<HrGenerateDraft>(
  context: context,
  builder: (dialogContext) =>
      _HrGeneratePayrollDialog(year: year, month: month),
);

class _HrGeneratePayrollDialog extends StatefulWidget {
  const _HrGeneratePayrollDialog({this.year, this.month});

  final int? year;
  final int? month;

  @override
  State<_HrGeneratePayrollDialog> createState() =>
      _HrGeneratePayrollDialogState();
}

class _HrGeneratePayrollDialogState extends State<_HrGeneratePayrollDialog> {
  final TextEditingController _note = TextEditingController();
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = widget.year ?? now.year;
    _month = widget.month ?? now.month;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _note.text.trim();
    Navigator.of(context).pop(
      HrGenerateDraft(
        periodYear: _year,
        periodMonth: _month,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now().year;
    return HrFormDialog(
      title: S.hrBtnGeneratePayroll,
      saveLabel: S.hrBtnGeneratePayroll,
      saveKey: const Key('hr-generate-save'),
      onSave: _submit,
      children: [
        // الدورة لقطة لا تعديل بعدها، فتُقرأ هذه الجملة قبل أي حقل.
        Text(
          S.hrGeneratePayrollHint,
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size10_5,
            height: AppTextHeights.line1_5,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        hrDropdownField<int>(
          context,
          label: S.hrFieldYear,
          value: _year,
          items: [
            for (final year in <int>[now - 1, now, now + 1])
              DropdownMenuItem(
                value: year,
                child: Text(localizeDigits('$year')),
              ),
          ],
          onChanged: (value) => setState(() => _year = value ?? _year),
        ),
        const SizedBox(height: AppSpacing.md),
        hrDropdownField<int>(
          context,
          label: S.hrFieldMonth,
          value: _month,
          items: [
            for (var m = 1; m <= 12; m++)
              DropdownMenuItem(value: m, child: Text(localizedMonthName(m))),
          ],
          onChanged: (value) => setState(() => _month = value ?? _month),
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
