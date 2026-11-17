class HrSchedule {
  const HrSchedule({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.branchId,
    required this.branchName,
    required this.start,
    required this.end,
    required this.breakMinutes,
    required this.status,
    this.note = '',
  });

  final String id;
  final String staffId;
  final String staffName;
  final String branchId;
  final String branchName;
  final DateTime start;
  final DateTime end;
  final int breakMinutes;
  final String status;
  final String note;

  factory HrSchedule.fromJson(Map<String, dynamic> json) => HrSchedule(
    id: '${json['id'] ?? ''}',
    staffId: '${json['staff_id'] ?? ''}',
    staffName: '${json['staff_name'] ?? ''}',
    branchId: '${json['branch_id'] ?? ''}',
    branchName: '${json['branch_name_en'] ?? json['branch_name_ar'] ?? ''}',
    start:
        DateTime.tryParse('${json['scheduled_start'] ?? ''}') ?? DateTime.now(),
    end: DateTime.tryParse('${json['scheduled_end'] ?? ''}') ?? DateTime.now(),
    breakMinutes: int.tryParse('${json['break_minutes'] ?? 0}') ?? 0,
    status: '${json['status'] ?? 'draft'}',
    note: '${json['note'] ?? ''}',
  );
}

class HrScheduleBranch {
  const HrScheduleBranch(this.id, this.nameAr, this.nameEn);
  final String id;
  final String nameAr;
  final String nameEn;

  factory HrScheduleBranch.fromJson(Map<String, dynamic> json) =>
      HrScheduleBranch(
        '${json['id'] ?? ''}',
        '${json['name_ar'] ?? ''}',
        '${json['name_en'] ?? ''}',
      );
}

class HrScheduleEmployee {
  const HrScheduleEmployee(this.id, this.name);
  final String id;
  final String name;

  factory HrScheduleEmployee.fromJson(Map<String, dynamic> json) =>
      HrScheduleEmployee(
        '${json['staff_id'] ?? ''}',
        '${json['full_name'] ?? json['email'] ?? ''}',
      );
}
