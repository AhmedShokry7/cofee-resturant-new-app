import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employee.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_date_field.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_form_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_labels.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:flutter/material.dart';

/// قيم سجل التوظيف كما يرسلها المدير، بنفس ترتيب وسمة `saveEmployment`.
///
/// الحقول التي تُترك فارغة تصل `null` لا نصًا فراغًا: الكتابة تكتب السجل كاملًا،
/// فالحقل الذي لم يُملَّح يُترك بلا قيمة لا بكلمة وهمية.
class HrEmploymentDraft {
  const HrEmploymentDraft({
    required this.staffId,
    this.employeeNumber,
    this.department,
    this.jobTitle,
    this.employmentType,
    this.employmentStatus,
    this.hiredOn,
    this.terminatedOn,
    this.phone,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.notes,
  });

  final String staffId;
  final String? employeeNumber;
  final String? department;
  final String? jobTitle;
  final String? employmentType;
  final String? employmentStatus;
  final DateTime? hiredOn;
  final DateTime? terminatedOn;
  final String? phone;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? notes;
}

/// حوار سجل التوظيف: العقد وحده، لا الهوية ولا الحساب ولا الصلاحية.
///
/// القيم تُزفّع من الموظف المفتوح لأن الكتابة تكتب السجل كما هو: حقل تُرك
/// فارغًا يُمحى من القاعدة، والشاشة لا تسأل المدير عن شيء لم ترَ قيمته.
Future<HrEmploymentDraft?> showHrEmploymentFormDialog(
  BuildContext context, {
  required HrEmployee? employee,
  required List<String> departments,
}) => showDialog<HrEmploymentDraft>(
  context: context,
  builder: (dialogContext) =>
      _HrEmploymentForm(employee: employee, departments: departments),
);

class _HrEmploymentForm extends StatefulWidget {
  const _HrEmploymentForm({required this.employee, required this.departments});

  final HrEmployee? employee;
  final List<String> departments;

  @override
  State<_HrEmploymentForm> createState() => _HrEmploymentFormState();
}

class _HrEmploymentFormState extends State<_HrEmploymentForm> {
  /// أنواع الارتباط التي يقيّدها CHECK في 212، بلفظها من خريطة الأنواع.
  static const List<String> _types = <String>[
    'full_time',
    'part_time',
    'temporary',
    'contract',
  ];

  /// حالات الارتباط المسموحة، وهي نفسها مرشّحات الدليل.
  static const List<String> _statuses = <String>[
    'active',
    'probation',
    'on_leave',
    'terminated',
  ];

  final TextEditingController _number = TextEditingController();
  final TextEditingController _jobTitle = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _emergencyName = TextEditingController();
  final TextEditingController _emergencyPhone = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  String? _department;
  String _type = 'full_time';
  String _status = 'active';
  DateTime? _hiredOn;
  DateTime? _terminatedOn;
  String? _error;

  @override
  void initState() {
    super.initState();
    final job = widget.employee?.employment ?? HrEmployment.none;
    _number.text = job.employeeNumber;
    _jobTitle.text = job.jobTitle;
    _phone.text = job.phone;
    _emergencyName.text = job.emergencyContactName;
    _emergencyPhone.text = job.emergencyContactPhone;
    _notes.text = job.notes;
    _type = _types.contains(job.employmentType)
        ? job.employmentType
        : 'full_time';
    _status = _statuses.contains(job.employmentStatus)
        ? job.employmentStatus
        : 'active';
    _hiredOn = job.hiredOn;
    _terminatedOn = job.terminatedOn;
    _department = job.department.isEmpty ? null : job.department;
  }

  /// الأقسام من المرجع، زائد القسم المكتوب في السجل إن لم يكن فيه: قائمة
  /// ترشيح لا تحوي قيمتها الحالية تسقط في خطأ تخطيط عند أول فتح.
  List<String> get _departmentOptions => <String>[
    ...widget.departments,
    if (_department != null && !widget.departments.contains(_department))
      _department!,
  ];

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _number,
      _jobTitle,
      _phone,
      _emergencyName,
      _emergencyPhone,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// التحقق المحلي: ما ترفضه القاعدة بحرفها يرفضه الحقل قبل أن يُهدر attempts.
  void _submit() {
    final staffId = widget.employee?.staffId ?? '';
    final number = _number.text.trim();
    if (staffId.isEmpty) {
      setState(() => _error = S.hrStaffMissing);
      return;
    }
    if (number.isEmpty) {
      setState(() => _error = S.hrNumberMissing);
      return;
    }
    final terminated = _terminatedOn;
    if (terminated != null &&
        _hiredOn != null &&
        terminated.isBefore(_hiredOn!)) {
      setState(() => _error = S.hrTerminationBeforeHire);
      return;
    }
    if (_status == 'terminated' && terminated == null) {
      setState(() => _error = S.hrTerminationDateRequired);
      return;
    }
    Navigator.of(context).pop(
      HrEmploymentDraft(
        staffId: staffId,
        employeeNumber: number,
        department: _department,
        jobTitle: _trimmed(_jobTitle),
        employmentType: _type,
        employmentStatus: _status,
        hiredOn: _hiredOn,
        terminatedOn: terminated,
        phone: _trimmed(_phone),
        emergencyContactName: _trimmed(_emergencyName),
        emergencyContactPhone: _trimmed(_emergencyPhone),
        notes: _trimmed(_notes),
      ),
    );
  }

  String? _trimmed(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return HrFormDialog(
      title: S.hrEmploymentTitle,
      error: _error,
      subtitle: widget.employee == null
          ? null
          : hrPersonName(widget.employee!.fullName),
      saveLabel: S.save,
      saveKey: const Key('hr-employment-save'),
      onSave: _submit,
      children: [
        _text(_number, S.hrColEmployeeNumber, required: true),
        _gap(
          hrDropdownField<String>(
            context,
            label: S.hrColDepartment,
            value: _department,
            // قائمة المرجع قد تكون خالية: تُقال للمدير ولا تُعرض فراغًا صامتًا.
            hint: widget.departments.isEmpty ? S.hrEmptyList : '',
            items: [
              for (final name in _departmentOptions)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: (value) => setState(() => _department = value),
          ),
        ),
        _gap(_text(_jobTitle, S.hrColJobTitle)),
        _gap(
          hrDropdownField<String>(
            context,
            label: S.hrFieldEmploymentType,
            value: _type,
            items: [
              for (final wire in _types)
                DropdownMenuItem(
                  value: wire,
                  child: Text(hrEmploymentTypeLabel(wire)),
                ),
            ],
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
        ),
        _gap(
          hrDropdownField<String>(
            context,
            label: S.hrFieldEmploymentStatus,
            value: _status,
            items: [
              for (final wire in _statuses)
                DropdownMenuItem(
                  value: wire,
                  child: Text(hrStatusLabel(wire).text),
                ),
            ],
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
        ),
        _gap(
          HrDateField(
            label: S.hrColHiredOn,
            value: _hiredOn,
            onChanged: (value) => setState(() => _hiredOn = value),
          ),
        ),
        _gap(
          HrDateField(
            label: S.hrFieldTerminatedOn,
            value: _terminatedOn,
            onChanged: (value) => setState(() => _terminatedOn = value),
          ),
        ),
        _gap(_text(_phone, S.hrFieldEmployeePhone, phone: true)),
        _gap(_text(_emergencyName, S.hrFieldEmergencyContact)),
        _gap(_text(_emergencyPhone, S.hrFieldEmergencyPhone, phone: true)),
        _gap(_text(_notes, S.hrFieldNote, multiline: true)),
      ],
    );
  }

  /// حقل نص بمقاس حقول الحوار، وحقول الهاتف بلوحة أرقام لأنها لا تُكتب حرفيًا.
  Widget _text(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool phone = false,
    bool multiline = false,
  }) => TextField(
    controller: controller,
    minLines: multiline ? 3 : null,
    maxLines: multiline ? 5 : null,
    keyboardType: phone ? TextInputType.phone : null,
    style: const TextStyle(fontSize: AppFontSizes.size12_5),
    decoration: adminDialogFieldDecoration(
      context,
      label: label,
      hint: '',
      required: required,
    ),
  );

  Widget _gap(Widget child) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md),
    child: child,
  );
}
