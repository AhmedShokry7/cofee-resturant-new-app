import 'package:admin_app/features/hr/domain/entities/hr_json.dart';

/// سجل التوظيف كما تكتبه `hr.employment_records` وتقرؤه `admin_hr_save_employment`.
///
/// يبقى مفصولًا عن هوية الموظف في `identity.staff_members`: الحساب هو من يدخل
/// اللوحة، والسجل وظيفته وأجره وحالته. لا يمنح سجل توظيف صلاحية وحده.
class HrEmployment {
  const HrEmployment({
    this.employeeNumber = '',
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

  final String employeeNumber;
  final String department;
  final String jobTitle;

  /// `full_time|part_time|temporary|contract` كما يقيّدها CHECK في 212.
  final String employmentType;

  /// `active|probation|on_leave|terminated`.
  final String employmentStatus;
  final DateTime? hiredOn;
  final DateTime? terminatedOn;
  final String phone;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String notes;

  bool get isTerminated => employmentStatus == 'terminated';
  bool get isActive => employmentStatus == 'active';

  static const HrEmployment none = HrEmployment();

  factory HrEmployment.fromJson(Map<String, dynamic> json) => HrEmployment(
    employeeNumber: hrText(json['employee_number']),
    department: hrText(json['department']),
    jobTitle: hrText(json['job_title']),
    employmentType: hrText(json['employment_type']).isEmpty
        ? 'full_time'
        : hrText(json['employment_type']),
    employmentStatus: hrText(json['employment_status']).isEmpty
        ? 'active'
        : hrText(json['employment_status']),
    hiredOn: hrDate(json['hired_on']),
    terminatedOn: hrDate(json['terminated_on']),
    phone: hrText(json['phone']),
    emergencyContactName: hrText(json['emergency_contact_name']),
    emergencyContactPhone: hrText(json['emergency_contact_phone']),
    notes: hrText(json['notes']),
  );
}

/// دور الموظف وفروعه، كما تقرأهما `identity.staff_roles` لا جدول HR.
class HrRoleAssignment {
  const HrRoleAssignment({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    this.branchId,
  });

  final String code;
  final String nameAr;
  final String nameEn;

  /// null = الدور على كل الفروع، وهو ما يعطي صاحبه نطاق العلامة كاملًا.
  final String? branchId;

  factory HrRoleAssignment.fromJson(Map<String, dynamic> json) =>
      HrRoleAssignment(
        code: hrText(json['code']),
        nameAr: hrText(json['name_ar']),
        nameEn: hrText(json['name_en']),
        branchId: hrId(json['branch_id']),
      );
}

/// صف في دليل الموظفين من `admin_hr_employees()`.
class HrEmployee {
  const HrEmployee({
    required this.staffId,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.accountStatus,
    required this.employment,
    this.avatarUrl,
    this.branches = const <String>[],
    this.roles = const <HrRoleAssignment>[],
  });

  final String staffId;
  final String userId;
  final String fullName;
  final String email;

  /// حالة الحساب في `identity.staff_members`، وهي غير حالة التوظيف.
  final String accountStatus;
  final HrEmployment employment;
  final String? avatarUrl;

  /// أسماء الفروع كما رتّبتها القاعدة، للعرض في العمود.
  final List<String> branches;
  final List<HrRoleAssignment> roles;

  bool get isTerminated => employment.isTerminated;

  factory HrEmployee.fromJson(Map<String, dynamic> json) => HrEmployee(
    staffId: hrText(json['staff_id']),
    userId: hrText(json['user_id']),
    fullName: hrText(json['full_name']),
    email: hrText(json['email']),
    accountStatus: hrText(json['account_status']),
    employment: HrEmployment.fromJson(hrMap(json)),
    avatarUrl: hrId(json['avatar_url']),
    branches: _branchNames(json['branches']),
    roles: hrMaps(json['roles']).map(HrRoleAssignment.fromJson).toList(),
  );

  /// ملف الموظف واحد: الهوية من الأعلى والتوظيف في `employment` المتعشّقة،
  /// فلا يُقرأ السجل من حروف الدليل المسطّحة ويُنسب إليه ما لم تكتبه القاعدة.
  factory HrEmployee.fromFileJson(Map<String, dynamic> json) => HrEmployee(
    staffId: hrText(json['staff_id']),
    userId: hrText(json['user_id']),
    fullName: hrText(json['full_name']),
    email: hrText(json['email']),
    accountStatus: hrText(json['account_status']),
    employment: json['employment'] == null
        ? HrEmployment.none
        : HrEmployment.fromJson(hrMap(json['employment'])),
    avatarUrl: hrId(json['avatar_url']),
    branches: _branchNames(json['branches']),
    roles: hrMaps(json['roles']).map(HrRoleAssignment.fromJson).toList(),
  );

  static List<String> _branchNames(Object? raw) => [
    for (final branch in hrMaps(raw))
      hrText(branch['name_ar']).isEmpty
          ? hrText(branch['name_en'])
          : hrText(branch['name_ar']),
  ];
}

/// قسيمة راتب نهائية كما تظهر في ملف الموظف.
class HrPayslipSummary {
  const HrPayslipSummary({
    required this.statementId,
    required this.runId,
    required this.periodYear,
    required this.periodMonth,
    required this.status,
    required this.gross,
    required this.deductionsTotal,
    required this.net,
    required this.currencyCode,
  });

  final String statementId;
  final String runId;
  final int periodYear;
  final int periodMonth;
  final String status;
  final double gross;
  final double deductionsTotal;
  final double net;
  final String currencyCode;

  factory HrPayslipSummary.fromJson(Map<String, dynamic> json) =>
      HrPayslipSummary(
        statementId: hrText(json['statement_id']),
        runId: hrText(json['run_id']),
        periodYear: hrInt(json['period_year']),
        periodMonth: hrInt(json['period_month']),
        status: hrText(json['run_status']),
        gross: hrNum(json['gross']),
        deductionsTotal: hrNum(json['deductions_total']),
        net: hrNum(json['net']),
        currencyCode: hrText(json['currency_code']),
      );
}

/// وجبة الحضور في ملف الموظف: ساعة القاعدة لا ساعة الجهاز.
class HrAttendanceBrief {
  const HrAttendanceBrief({
    required this.id,
    required this.branchName,
    required this.clockIn,
    required this.clockOut,
    required this.clockInLocal,
    required this.clockOutLocal,
    required this.isOpen,
  });

  final String id;
  final String branchName;

  /// الطابعان بالحسابة UTC كما ترسلهما القاعدة.
  final DateTime? clockIn;
  final DateTime? clockOut;

  /// النص المحلي جاهزًا من `hr.fmt_ts`: المنطقة التجارية لا متصفح الجهاز.
  final String clockInLocal;
  final String clockOutLocal;
  final bool isOpen;

  factory HrAttendanceBrief.fromJson(Map<String, dynamic> json) =>
      HrAttendanceBrief(
        id: hrText(json['id']),
        branchName: hrText(json['branch_name_ar']).isEmpty
            ? hrText(json['branch_name_en'])
            : hrText(json['branch_name_ar']),
        clockIn: hrDate(json['clock_in']),
        clockOut: hrDate(json['clock_out']),
        clockInLocal: hrText(json['clock_in_local']),
        clockOutLocal: hrText(json['clock_out_local']),
        isOpen: hrBool(json['is_open']),
      );
}

/// وردية صندوق سجلها هذا الموظف، من `payments.pos_shifts` عبر ملف الموظف.
class HrCashierShift {
  const HrCashierShift({
    required this.id,
    required this.status,
    required this.openedAtLocal,
    required this.closedAtLocal,
    required this.variance,
    required this.currencyCode,
  });

  final String id;
  final String status;
  final String openedAtLocal;
  final String closedAtLocal;

  /// الفرق المحسوب في القاعدة: عدّاد الإغلاق ناقص المتوقع.
  final double variance;
  final String currencyCode;

  bool get hasShortage => variance < 0;

  factory HrCashierShift.fromJson(Map<String, dynamic> json) => HrCashierShift(
    id: hrText(json['id']),
    status: hrText(json['status']),
    openedAtLocal: hrText(json['opened_at_local']),
    closedAtLocal: hrText(json['closed_at_local']),
    variance: hrNum(json['variance']),
    currencyCode: hrText(json['currency_code']),
  );
}
