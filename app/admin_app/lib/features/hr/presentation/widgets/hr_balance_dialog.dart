import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_form_dialog.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:flutter/material.dart';

/// حوار رصيد الإجازة: الاستحقاق بالسنة، والرصيد تحسبه القاعدة من المطبقات.
///
/// لا يُطلب «المتبقي» هنا لأن 212 تطرح المستخدَم من المستحق؛ كتابة المتبقي
/// يدويًا كانت تكذب أول مرة تُعتمد فيها إجازة.
Future<HrBalanceDraft?> showHrBalanceDialog(
  BuildContext context, {
  required List<HrPersonOption>? people,
  required List<HrLeaveType> leaveTypes,
}) => showDialog<HrBalanceDraft>(
  context: context,
  builder: (dialogContext) =>
      _HrBalanceDialog(people: people, leaveTypes: leaveTypes),
);

/// قيم رصيد إجازة يرسلها المدير: موظف، ونوع، وسنة، وأيام استحقاق.
class HrBalanceDraft {
  const HrBalanceDraft({
    required this.staffId,
    required this.leaveTypeId,
    required this.year,
    required this.entitledDays,
  });

  final String staffId;
  final String leaveTypeId;
  final int year;
  final double entitledDays;
}

class _HrBalanceDialog extends StatefulWidget {
  const _HrBalanceDialog({required this.people, required this.leaveTypes});

  final List<HrPersonOption>? people;
  final List<HrLeaveType> leaveTypes;

  @override
  State<_HrBalanceDialog> createState() => _HrBalanceDialogState();
}

class _HrBalanceDialogState extends State<_HrBalanceDialog> {
  final TextEditingController _days = TextEditingController();
  String? _staffId;
  String? _typeId;
  int _year = DateTime.now().year;
  String? _error;

  @override
  void initState() {
    super.initState();
    _staffId = hrFirstPersonId(widget.people);
    _typeId = widget.leaveTypes.isEmpty ? null : widget.leaveTypes.first.id;
  }

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  void _submit() {
    final days = double.tryParse(_days.text.trim());
    if (_staffId == null || _typeId == null) {
      setState(() => _error = S.hrStaffMissing);
      return;
    }
    if (days == null || days < 0) {
      setState(() => _error = S.hrNumberMissing);
      return;
    }
    Navigator.of(context).pop(
      HrBalanceDraft(
        staffId: _staffId!,
        leaveTypeId: _typeId!,
        year: _year,
        entitledDays: days,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HrFormDialog(
      title: S.hrBalanceTitle,
      error: _error,
      saveLabel: S.hrBtnSetBalance,
      saveKey: const Key('hr-balance-save'),
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
          label: S.hrFieldLeaveType,
          value: _typeId,
          hint: S.hrNoLeaveTypesRead,
          items: [
            for (final type in widget.leaveTypes)
              DropdownMenuItem(
                value: type.id,
                child: Text(hrLeaveTypeName(type)),
              ),
          ],
          onChanged: (value) => setState(() => _typeId = value),
        ),
        const SizedBox(height: AppSpacing.md),
        hrDropdownField<int>(
          context,
          label: S.hrFieldYear,
          value: _year,
          items: [
            for (final year in _years())
              DropdownMenuItem(
                value: year,
                child: Text(localizeDigits('$year')),
              ),
          ],
          onChanged: (value) => setState(() => _year = value ?? _year),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _days,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: AppFontSizes.size12_5),
          decoration: adminDialogFieldDecoration(
            context,
            label: S.hrFieldEntitledDays,
            hint: S.hrAmountHint,
            required: true,
          ),
        ),
      ],
    );
  }

  /// ثلاث سنوات حول اليوم: رصيد سنة ولدت أو ستولد ليس قرارًا يُتخذ من هذه الشاشة.
  List<int> _years() {
    final now = DateTime.now().year;
    return <int>[now - 1, now, now + 1];
  }
}
