import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/hr/domain/entities/hr_employment_draft.dart';
import 'package:admin_app/features/hr/presentation/strings/hr_employee_strings.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

class HrEmploymentEditForm extends StatefulWidget {
  const HrEmploymentEditForm({
    super.key,
    required this.initial,
    required this.saving,
    required this.errorMessage,
    required this.onCancel,
    required this.onSave,
  });

  final HrEmploymentDraft initial;
  final bool saving;
  final String? errorMessage;
  final VoidCallback onCancel;
  final Future<bool> Function(HrEmploymentDraft) onSave;

  @override
  State<HrEmploymentEditForm> createState() => _HrEmploymentEditFormState();
}

class _HrEmploymentEditFormState extends State<HrEmploymentEditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _employeeNumber;
  late final TextEditingController _department;
  late final TextEditingController _jobTitle;
  late final TextEditingController _hireDate;
  late final TextEditingController _terminationDate;
  late final TextEditingController _phone;
  late final TextEditingController _emergencyName;
  late final TextEditingController _emergencyPhone;
  late final TextEditingController _notes;
  late String _type;
  late String _status;

  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    _employeeNumber = TextEditingController(text: value.employeeNumber ?? '');
    _department = TextEditingController(text: value.department);
    _jobTitle = TextEditingController(text: value.jobTitle);
    _hireDate = TextEditingController(text: _formatDate(value.hiredOn));
    _terminationDate = TextEditingController(
      text: _formatDate(value.terminatedOn),
    );
    _phone = TextEditingController(text: value.phone);
    _emergencyName = TextEditingController(text: value.emergencyContactName);
    _emergencyPhone = TextEditingController(text: value.emergencyContactPhone);
    _notes = TextEditingController(text: value.notes);
    _type = value.employmentType;
    _status = value.employmentStatus;
  }

  @override
  void dispose() {
    _employeeNumber.dispose();
    _department.dispose();
    _jobTitle.dispose();
    _hireDate.dispose();
    _terminationDate.dispose();
    _phone.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    _notes.dispose();
    super.dispose();
  }

  static String _formatDate(DateTime? date) => date == null
      ? ''
      : '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';

  DateTime? _parsedDate(String value) =>
      value.trim().isEmpty ? null : DateTime.tryParse(value.trim());

  String? _dateValidator(String? value) {
    if (value == null || value.trim().isEmpty || _parsedDate(value) != null) {
      return null;
    }
    return HrEmployeeStrings.invalidDate;
  }

  String? _terminationValidator(String? value) {
    final base = _dateValidator(value);
    if (base != null) return base;
    if (_status == 'terminated' && (value == null || value.trim().isEmpty)) {
      return HrEmployeeStrings.terminationRequired;
    }
    final hire = _parsedDate(_hireDate.text);
    final termination = _parsedDate(value ?? '');
    if (hire != null && termination != null && termination.isBefore(hire)) {
      return HrEmployeeStrings.terminationBeforeHire;
    }
    return null;
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final initial = _parsedDate(controller.text) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    controller.text = _formatDate(date);
    _formKey.currentState?.validate();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await widget.onSave(
      HrEmploymentDraft(
        employeeNumber: _employeeNumber.text.trim().isEmpty
            ? null
            : _employeeNumber.text.trim(),
        department: _department.text.trim(),
        jobTitle: _jobTitle.text.trim(),
        employmentType: _type,
        employmentStatus: _status,
        hiredOn: _parsedDate(_hireDate.text),
        terminatedOn: _parsedDate(_terminationDate.text),
        phone: _phone.text.trim(),
        emergencyContactName: _emergencyName.text.trim(),
        emergencyContactPhone: _emergencyPhone.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
    if (result && mounted) widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (widget.errorMessage != null) ...[
                  AdminInlineError(message: widget.errorMessage!),
                  const SizedBox(height: AppSpacing.md),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 620 ? 2 : 1;
                    return _FieldsGrid(
                      columns: columns,
                      children: [
                        _field(
                          HrEmployeeStrings.employeeNumber,
                          _employeeNumber,
                        ),
                        _field(
                          HrEmployeeStrings.department,
                          _department,
                          maxLength: 80,
                        ),
                        _field(
                          HrEmployeeStrings.jobTitle,
                          _jobTitle,
                          maxLength: 80,
                        ),
                        _dropdown(
                          HrEmployeeStrings.employmentType,
                          _type,
                          <DropdownMenuItem<String>>[
                            DropdownMenuItem(
                              value: 'full_time',
                              child: Text(HrEmployeeStrings.fullTime),
                            ),
                            DropdownMenuItem(
                              value: 'part_time',
                              child: Text(HrEmployeeStrings.partTime),
                            ),
                            DropdownMenuItem(
                              value: 'contract',
                              child: Text(HrEmployeeStrings.contract),
                            ),
                          ],
                          (value) => setState(() => _type = value!),
                        ),
                        _dropdown(
                          HrEmployeeStrings.employmentStatus,
                          _status,
                          <DropdownMenuItem<String>>[
                            DropdownMenuItem(
                              value: 'active',
                              child: Text(HrEmployeeStrings.active),
                            ),
                            DropdownMenuItem(
                              value: 'probation',
                              child: Text(HrEmployeeStrings.probation),
                            ),
                            DropdownMenuItem(
                              value: 'on_leave',
                              child: Text(HrEmployeeStrings.onLeave),
                            ),
                            DropdownMenuItem(
                              value: 'terminated',
                              child: Text(HrEmployeeStrings.terminated),
                            ),
                          ],
                          (value) => setState(() {
                            _status = value!;
                            _formKey.currentState?.validate();
                          }),
                        ),
                        _dateField(
                          HrEmployeeStrings.hireDate,
                          _hireDate,
                          _dateValidator,
                        ),
                        _dateField(
                          HrEmployeeStrings.terminationDate,
                          _terminationDate,
                          _terminationValidator,
                        ),
                        _field(HrEmployeeStrings.phone, _phone, maxLength: 40),
                        _field(
                          HrEmployeeStrings.emergencyName,
                          _emergencyName,
                          maxLength: 80,
                        ),
                        _field(
                          HrEmployeeStrings.emergencyPhone,
                          _emergencyPhone,
                          maxLength: 40,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _notes,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: adminDialogFieldDecoration(
                    context,
                    label: HrEmployeeStrings.notes,
                    hint: HrEmployeeStrings.notes,
                  ),
                ),
              ],
            ),
          ),
        ),
        AdminDialogFooter(
          saving: widget.saving,
          onCancel: widget.onCancel,
          onSave: _submit,
          saveKey: const Key('hr-employment-save'),
          saveLabel: HrEmployeeStrings.save,
          savingLabel: HrEmployeeStrings.saving,
          cancelLabel: HrEmployeeStrings.cancel,
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int? maxLength,
  }) => TextFormField(
    controller: controller,
    maxLength: maxLength,
    inputFormatters: maxLength == null
        ? const <TextInputFormatter>[]
        : <TextInputFormatter>[LengthLimitingTextInputFormatter(maxLength)],
    decoration: adminDialogFieldDecoration(context, label: label, hint: label),
  );

  Widget _dateField(
    String label,
    TextEditingController controller,
    FormFieldValidator<String> validator,
  ) => TextFormField(
    controller: controller,
    readOnly: true,
    validator: validator,
    onTap: () => _pickDate(controller),
    decoration:
        adminDialogFieldDecoration(
          context,
          label: label,
          hint: 'YYYY-MM-DD',
        ).copyWith(
          suffixIcon: IconButton(
            tooltip: HrEmployeeStrings.date,
            onPressed: () => _pickDate(controller),
            icon: const AppIcon(AppIcons.calendar01, size: 18),
          ),
        ),
  );

  Widget _dropdown(
    String label,
    String value,
    List<DropdownMenuItem<String>> items,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    items: items,
    onChanged: widget.saving ? null : onChanged,
    decoration: adminDialogFieldDecoration(context, label: label, hint: label),
  );
}

class _FieldsGrid extends StatelessWidget {
  const _FieldsGrid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (columns == 1) {
      return Column(
        children: [
          for (final child in children) ...[
            child,
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      );
    }
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final child in children)
          SizedBox(
            width: (MediaQuery.sizeOf(context).width - 120) / 2,
            child: child,
          ),
      ],
    );
  }
}
