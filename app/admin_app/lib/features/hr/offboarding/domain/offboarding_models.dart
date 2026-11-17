class HrOffboardingPerson {
  const HrOffboardingPerson({
    required this.staffId,
    required this.name,
    required this.email,
  });

  final String staffId;
  final String name;
  final String email;

  factory HrOffboardingPerson.fromJson(Map<String, dynamic> json) =>
      HrOffboardingPerson(
        staffId: '${json['staff_id'] ?? ''}',
        name: '${json['full_name'] ?? ''}',
        email: '${json['email'] ?? ''}',
      );
}

class HrOffboardingStep {
  const HrOffboardingStep({
    required this.code,
    required this.status,
    this.ownerStaffId,
    this.ownerName,
    this.dueOn,
    this.note = '',
    this.doneByName,
    this.doneAt,
  });

  final String code;
  final String status;
  final String? ownerStaffId;
  final String? ownerName;
  final DateTime? dueOn;
  final String note;
  final String? doneByName;
  final DateTime? doneAt;

  factory HrOffboardingStep.fromJson(Map<String, dynamic> json) =>
      HrOffboardingStep(
        code: '${json['code'] ?? ''}',
        status: '${json['status'] ?? 'pending'}',
        ownerStaffId: _optional(json['owner_staff_id']),
        ownerName: _optional(json['owner_name']),
        dueOn: _date(json['due_on']),
        note: '${json['note'] ?? ''}',
        doneByName: _optional(json['done_by_name']),
        doneAt: _date(json['done_at']),
      );
}

class HrOffboardingCase {
  const HrOffboardingCase({
    required this.caseId,
    required this.staffId,
    required this.staffName,
    required this.status,
    required this.employmentStatus,
    required this.steps,
    this.lastWorkingOn,
    this.settlementNote = '',
    this.requestedByName,
    this.finalizedByName,
    this.finalizedAt,
    this.cancelledNote = '',
    this.createdAt,
  });

  final String caseId;
  final String staffId;
  final String staffName;
  final String status;
  final String employmentStatus;
  final DateTime? lastWorkingOn;
  final String settlementNote;
  final String? requestedByName;
  final String? finalizedByName;
  final DateTime? finalizedAt;
  final String cancelledNote;
  final DateTime? createdAt;
  final List<HrOffboardingStep> steps;

  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';
  HrOffboardingStep? step(String code) {
    for (final item in steps) {
      if (item.code == code) return item;
    }
    return null;
  }

  factory HrOffboardingCase.fromJson(Map<String, dynamic> json) =>
      HrOffboardingCase(
        caseId: '${json['case_id'] ?? ''}',
        staffId: '${json['staff_id'] ?? ''}',
        staffName: '${json['staff_name'] ?? ''}',
        status: '${json['status'] ?? 'open'}',
        employmentStatus: '${json['employment_status'] ?? ''}',
        lastWorkingOn: _date(json['last_working_on']),
        settlementNote: '${json['settlement_note'] ?? ''}',
        requestedByName: _optional(json['requested_by_name']),
        finalizedByName: _optional(json['finalized_by_name']),
        finalizedAt: _date(json['finalized_at']),
        cancelledNote: '${json['cancelled_note'] ?? ''}',
        createdAt: _date(json['created_at']),
        steps: json['steps'] is List
            ? (json['steps'] as List)
                  .whereType<Map>()
                  .map(
                    (row) => HrOffboardingStep.fromJson(
                      Map<String, dynamic>.from(row),
                    ),
                  )
                  .toList(growable: false)
            : const [],
      );
}

String? _optional(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _date(Object? value) => value == null
    ? null
    : value is DateTime
    ? value
    : DateTime.tryParse(value.toString());
