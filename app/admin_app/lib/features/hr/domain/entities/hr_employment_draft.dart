class HrEmploymentDraft {
  const HrEmploymentDraft({
    this.employeeNumber,
    this.department = '',
    this.jobTitle = '',
    this.employmentType = 'full_time',
    this.employmentStatus = 'active',
    this.hiredOn,
    this.terminatedOn,
    this.phone = '',
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.notes = '',
  });

  final String? employeeNumber;
  final String department;
  final String jobTitle;
  final String employmentType;
  final String employmentStatus;
  final DateTime? hiredOn;
  final DateTime? terminatedOn;
  final String phone;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String notes;

  factory HrEmploymentDraft.fromJson(Map<String, dynamic>? json) {
    DateTime? date(Object? value) =>
        value == null ? null : DateTime.tryParse('$value');

    return HrEmploymentDraft(
      employeeNumber: json?['employee_number'] as String?,
      department: '${json?['department'] ?? ''}',
      jobTitle: '${json?['job_title'] ?? ''}',
      employmentType: '${json?['employment_type'] ?? 'full_time'}',
      employmentStatus: '${json?['employment_status'] ?? 'active'}',
      hiredOn: date(json?['hired_on']),
      terminatedOn: date(json?['terminated_on']),
      phone: '${json?['phone'] ?? ''}',
      emergencyContactName: '${json?['emergency_contact_name'] ?? ''}',
      emergencyContactPhone: '${json?['emergency_contact_phone'] ?? ''}',
      notes: '${json?['notes'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson({required String staffId}) => <String, dynamic>{
    'p_staff_id': staffId,
    'p_employee_number': employeeNumber,
    'p_department': department,
    'p_job_title': jobTitle,
    'p_employment_type': employmentType,
    'p_employment_status': employmentStatus,
    'p_hired_on': _dateOnly(hiredOn),
    'p_terminated_on': _dateOnly(terminatedOn),
    'p_phone': phone,
    'p_emergency_contact_name': emergencyContactName,
    'p_emergency_contact_phone': emergencyContactPhone,
    'p_notes': notes,
  };

  static String? _dateOnly(DateTime? value) => value == null
      ? null
      : '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}';
}
