import 'package:admin_app/features/hr/domain/entities/hr_json.dart';

/// معاينة دورة الرواتب كما تردّها `admin_hr_preview_payroll`: قراءة نقية
/// قبل أي كتابة، بحساب مرآة لمنطق التوليد لا تخمينًا من الشاشة.
///
/// الأرقام كلها من القاعدة، وما لم تردّه يبقى غائبًا لا صفرًا — نفس انضباط
/// `hr_json.dart` في بقية HR.
class HrPayrollPreview {
  const HrPayrollPreview({
    required this.periodYear,
    required this.periodMonth,
    required this.employees,
    required this.adjustmentsDue,
    required this.missingData,
    this.run,
    this.policy,
    this.previousMonth,
  });

  final int periodYear;
  final int periodMonth;

  /// الدورة الموجودة للفترة إن وُجدت، وحالتها الحقيقية.
  final HrPayrollPreviewRun? run;
  final HrPayrollPreviewPolicy? policy;
  final HrPayrollPreviewPrevious? previousMonth;
  final List<HrPayrollPreviewEmployee> employees;
  final List<HrAdjustmentDue> adjustmentsDue;
  final List<HrPayrollMissing> missingData;

  static const HrPayrollPreview none = HrPayrollPreview(
    periodYear: 0,
    periodMonth: 0,
    employees: [],
    adjustmentsDue: [],
    missingData: [],
  );

  bool get isReal => periodYear != 0;

  factory HrPayrollPreview.fromJson(Map<String, dynamic> json) =>
      HrPayrollPreview(
        periodYear: hrInt(json['period_year']),
        periodMonth: hrInt(json['period_month']),
        run: json['run'] == null
            ? null
            : HrPayrollPreviewRun.fromJson(hrMap(json['run'])),
        policy: json['policy'] == null
            ? null
            : HrPayrollPreviewPolicy.fromJson(hrMap(json['policy'])),
        previousMonth: json['previous_month'] == null
            ? null
            : HrPayrollPreviewPrevious.fromJson(hrMap(json['previous_month'])),
        employees: hrMaps(json['employees'])
            .map(HrPayrollPreviewEmployee.fromJson)
            .toList(),
        adjustmentsDue: hrMaps(json['adjustments_due'])
            .map(HrAdjustmentDue.fromJson)
            .toList(),
        missingData: hrMaps(json['missing_data'])
            .map(HrPayrollMissing.fromJson)
            .toList(),
      );
}

/// كتلة الدورة داخل المعاينة: ما قُرئ من القاعدة لا مُلخّص من الشاشة.
class HrPayrollPreviewRun {
  const HrPayrollPreviewRun({
    required this.runId,
    required this.status,
    required this.calcSeq,
    required this.statementCount,
    required this.totalGross,
    required this.totalDeductions,
    required this.totalNet,
    this.closedAt,
  });

  final String runId;
  final String status;
  final int calcSeq;
  final int statementCount;
  final double totalGross;
  final double totalDeductions;
  final double totalNet;
  final DateTime? closedAt;

  factory HrPayrollPreviewRun.fromJson(Map<String, dynamic> json) =>
      HrPayrollPreviewRun(
        runId: hrText(json['run_id']),
        status: hrText(json['status']),
        calcSeq: hrInt(json['calc_seq']),
        statementCount: hrInt(json['statement_count']),
        totalGross: hrNum(json['total_gross']),
        totalDeductions: hrNum(json['total_deductions']),
        totalNet: hrNum(json['total_net']),
        closedAt: hrDate(json['closed_at']),
      );
}

/// سياسة الحسم كما تردّها المعاينة لصاحب `hr.payroll.manage`.
class HrPayrollPreviewPolicy {
  const HrPayrollPreviewPolicy({
    required this.absenceDayRate,
    required this.lateMinuteRate,
    required this.earlyMinuteRate,
    required this.unpaidLeaveDayRate,
    required this.maxSalaryDeductionPercent,
    required this.cashierDeductionAllowed,
  });

  final double absenceDayRate;
  final double lateMinuteRate;
  final double earlyMinuteRate;
  final double unpaidLeaveDayRate;
  final double maxSalaryDeductionPercent;
  final bool cashierDeductionAllowed;

  factory HrPayrollPreviewPolicy.fromJson(Map<String, dynamic> json) =>
      HrPayrollPreviewPolicy(
        absenceDayRate: hrNum(json['absence_day_rate']),
        lateMinuteRate: hrNum(json['late_minute_rate']),
        earlyMinuteRate: hrNum(json['early_minute_rate']),
        unpaidLeaveDayRate: hrNum(json['unpaid_leave_day_rate']),
        maxSalaryDeductionPercent: hrNum(json['max_salary_deduction_percent']),
        cashierDeductionAllowed: hrBool(json['cashier_deduction_allowed']),
      );
}

/// الشهر السابق المصروف، لمقارنة الصافي مقارنةً مصدرها القاعدة.
class HrPayrollPreviewPrevious {
  const HrPayrollPreviewPrevious({
    required this.periodYear,
    required this.periodMonth,
    required this.status,
    required this.statementCount,
    required this.totalGross,
    required this.totalDeductions,
    required this.totalNet,
  });

  final int periodYear;
  final int periodMonth;
  final String status;
  final int statementCount;
  final double totalGross;
  final double totalDeductions;
  final double totalNet;

  factory HrPayrollPreviewPrevious.fromJson(Map<String, dynamic> json) =>
      HrPayrollPreviewPrevious(
        periodYear: hrInt(json['period_year']),
        periodMonth: hrInt(json['period_month']),
        status: hrText(json['status']),
        statementCount: hrInt(json['statement_count']),
        totalGross: hrNum(json['total_gross']),
        totalDeductions: hrNum(json['total_deductions']),
        totalNet: hrNum(json['total_net']),
      );
}

/// موظف واحد في المعاينة: من التعويض إلى الصافي المتوقع بأسطر مصدره.
class HrPayrollPreviewEmployee {
  const HrPayrollPreviewEmployee({
    required this.staffId,
    required this.staffName,
    required this.compensationId,
    required this.basicSalary,
    required this.allowancesTotal,
    required this.gross,
    required this.absenceDays,
    required this.lateMinutes,
    required this.earlyMinutes,
    required this.paidLeaveDays,
    required this.unpaidLeaveDays,
    required this.attendanceDeduction,
    required this.attendanceDeductionBase,
    required this.unpaidLeaveDeduction,
    required this.additionsTotal,
    required this.otherDeductions,
    required this.advancePlanned,
    required this.netPreview,
    required this.lines,
    this.compensationFrom,
    this.previousNet,
  });

  final String staffId;
  final String staffName;
  final String compensationId;
  final DateTime? compensationFrom;
  final double basicSalary;
  final double allowancesTotal;
  final double gross;
  final int absenceDays;
  final int lateMinutes;
  final int earlyMinutes;
  final int paidLeaveDays;
  final int unpaidLeaveDays;
  final double attendanceDeduction;

  /// حصة `@attendance` وحدها (الغياب والتأخير والمبكر) بعد الانفصال عن
  /// `@unpaid_leave` الذي أدخلته المرحلة الثانية.
  final double attendanceDeductionBase;
  final double unpaidLeaveDeduction;
  final double additionsTotal;
  final double otherDeductions;
  final double advancePlanned;
  final double netPreview;
  final double? previousNet;
  final List<HrPayrollPreviewLine> lines;

  factory HrPayrollPreviewEmployee.fromJson(Map<String, dynamic> json) =>
      HrPayrollPreviewEmployee(
        staffId: hrText(json['staff_id']),
        staffName: hrText(json['staff_name']),
        compensationId: hrText(json['compensation_id']),
        compensationFrom: hrDate(json['compensation_from']),
        basicSalary: hrNum(json['basic_salary']),
        allowancesTotal: hrNum(json['allowances_total']),
        gross: hrNum(json['gross']),
        absenceDays: hrInt(json['absence_days']),
        lateMinutes: hrInt(json['late_minutes']),
        earlyMinutes: hrInt(json['early_minutes']),
        paidLeaveDays: hrInt(json['paid_leave_days']),
        unpaidLeaveDays: hrInt(json['unpaid_leave_days']),
        attendanceDeduction: hrNum(json['attendance_deduction']),
        attendanceDeductionBase: hrNum(json['attendance_deduction_base']),
        unpaidLeaveDeduction: hrNum(json['unpaid_leave_deduction']),
        additionsTotal: hrNum(json['additions_total']),
        otherDeductions: hrNum(json['other_deductions']),
        advancePlanned: hrNum(json['advance_planned']),
        netPreview: hrNum(json['net_preview']),
        previousNet: json['previous_net'] == null
            ? null
            : hrNum(json['previous_net']),
        lines: hrMaps(json['lines'])
            .map(HrPayrollPreviewLine.fromJson)
            .toList(),
      );
}

/// سطر مطالبة متوقع في المعاينة: `deferred` أو `cap_blocked` أو `suspended`
/// أو `advance` أو `due` — الحالات التي عدّلت D2–D4 على مسار المطالبة.
class HrPayrollPreviewLine {
  const HrPayrollPreviewLine({
    required this.kind,
    required this.state,
    required this.label,
    required this.amount,
  });

  final String kind;
  final String state;
  final String label;
  final double amount;

  factory HrPayrollPreviewLine.fromJson(Map<String, dynamic> json) =>
      HrPayrollPreviewLine(
        kind: hrText(json['kind']),
        state: hrText(json['state']),
        label: hrText(json['label']),
        amount: hrNum(json['amount']),
      );
}

/// تسوية معتمدة غير مطالَبة تستحق في الفترة أو قبلها — الترحيل الذي
/// يعد به D2 ويظهر في المعاينة قبل أن يحدث.
class HrAdjustmentDue {
  const HrAdjustmentDue({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.kind,
    required this.amount,
    required this.reason,
    required this.sourceType,
    required this.deferred,
    this.dueDate,
  });

  final String id;
  final String staffId;
  final String staffName;
  final String kind;
  final double amount;
  final String reason;
  final String sourceType;
  final bool deferred;
  final DateTime? dueDate;

  factory HrAdjustmentDue.fromJson(Map<String, dynamic> json) =>
      HrAdjustmentDue(
        id: hrText(json['id']),
        staffId: hrText(json['staff_id']),
        staffName: hrText(json['staff_name']),
        kind: hrText(json['kind']),
        amount: hrNum(json['amount']),
        reason: hrText(json['reason']),
        sourceType: hrText(json['source_type']),
        deferred: hrBool(json['deferred']),
        dueDate: hrDate(json['due_date']),
      );
}

/// موظف نشط بلا تعويض يغطي الفترة: يُحذف من التوليد بصمت اليوم، والمعاينة
/// تسمّيه حتى لا يضيع راتبه من غير قرار.
class HrPayrollMissing {
  const HrPayrollMissing({
    required this.staffId,
    required this.staffName,
    required this.reason,
  });

  final String staffId;
  final String staffName;
  final String reason;

  factory HrPayrollMissing.fromJson(Map<String, dynamic> json) =>
      HrPayrollMissing(
        staffId: hrText(json['staff_id']),
        staffName: hrText(json['staff_name']),
        reason: hrText(json['reason']),
      );
}
