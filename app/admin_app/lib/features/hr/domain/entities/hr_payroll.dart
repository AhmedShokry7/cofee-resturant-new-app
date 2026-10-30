import 'package:admin_app/features/hr/domain/entities/hr_json.dart';

/// مصدر سطر في قسيمة الراتب، كما تسميه 212 في `payroll_line_items`.
class HrPayrollLine {
  const HrPayrollLine({
    required this.id,
    required this.kind,
    required this.category,
    required this.sourceType,
    required this.sourceId,
    required this.label,
    required this.amount,
  });

  final String id;

  /// `addition` أو `deduction`: اتجاه المبلغ لا اسمه.
  final String kind;

  /// `basic|allowance|bonus|commission|overtime|attendance|advance|discrepancy|other`.
  final String category;
  final String sourceType;
  final String sourceId;
  final String label;
  final double amount;

  bool get isAddition => kind == 'addition';

  factory HrPayrollLine.fromJson(Map<String, dynamic> json) => HrPayrollLine(
    id: hrText(json['id']),
    kind: hrText(json['kind']),
    category: hrText(json['category']),
    sourceType: hrText(json['source_type']),
    sourceId: hrText(json['source_id']),
    label: hrText(json['label']),
    amount: hrNum(json['amount']),
  );
}

/// قسيمة راتب واحدة، وهي لقطة الحساب المحفوظة لا رقم يُعاد جمعه.
///
/// الأرقام كلها من القاعدة: `gross` و`net` كتبت في الصف عند الحساب، فالعرض
/// يقرأها كما هي. لو جمعت الشاشة الأسطر لظهر مبلغ يختلف عن المعتمد.
class HrPayrollStatement {
  const HrPayrollStatement({
    required this.statementId,
    required this.runId,
    required this.staffId,
    required this.staffName,
    required this.employeeNumber,
    required this.periodYear,
    required this.periodMonth,
    required this.runStatus,
    required this.basicSalary,
    required this.allowancesTotal,
    required this.additionsTotal,
    required this.attendanceDeduction,
    required this.advanceDeduction,
    required this.otherDeductions,
    required this.deductionsTotal,
    required this.absenceDays,
    required this.lateMinutes,
    required this.earlyMinutes,
    required this.gross,
    required this.net,
    required this.currencyCode,
    required this.calculationVersion,
    required this.lines,
  });

  final String statementId;
  final String runId;
  final String staffId;
  final String staffName;
  final String employeeNumber;
  final int periodYear;
  final int periodMonth;

  /// حالة الدورة التي تحمل القسيمة، لا حالة القسيمة نفسها.
  final String runStatus;
  final double basicSalary;
  final double allowancesTotal;
  final double additionsTotal;

  /// الحسم المناظر للتأخير والغياب، حسب أسعار `hr.settings`.
  final double attendanceDeduction;

  /// ما نزل من السلفة في هذه الدورة فقط.
  final double advanceDeduction;
  final double otherDeductions;
  final double deductionsTotal;
  final int absenceDays;
  final int lateMinutes;
  final int earlyMinutes;
  final double gross;
  final double net;
  final String currencyCode;

  /// إصدار الحساب الذي اعتمد هذه القسيمة، للرجع عند الطعن.
  final String calculationVersion;
  final List<HrPayrollLine> lines;

  factory HrPayrollStatement.fromJson(Map<String, dynamic> json) =>
      HrPayrollStatement(
        statementId: hrText(json['statement_id']),
        runId: hrText(json['run_id']),
        staffId: hrText(json['staff_id']),
        staffName: hrText(json['staff_name']),
        employeeNumber: hrText(json['employee_number']),
        periodYear: hrInt(json['period_year']),
        periodMonth: hrInt(json['period_month']),
        runStatus: hrText(json['run_status']),
        basicSalary: hrNum(json['basic_salary']),
        allowancesTotal: hrNum(json['allowances_total']),
        additionsTotal: hrNum(json['additions_total']),
        attendanceDeduction: hrNum(json['attendance_deduction']),
        advanceDeduction: hrNum(json['advance_deduction']),
        otherDeductions: hrNum(json['other_deductions']),
        deductionsTotal: hrNum(json['deductions_total']),
        absenceDays: hrInt(json['absence_days']),
        lateMinutes: hrInt(json['late_minutes']),
        earlyMinutes: hrInt(json['early_minutes']),
        gross: hrNum(json['gross']),
        net: hrNum(json['net']),
        currencyCode: hrText(json['currency_code']),
        calculationVersion: hrText(json['calculation_version']),
        lines: hrMaps(json['lines']).map(HrPayrollLine.fromJson).toList(),
      );
}

/// دورة رواتب من `admin_hr_payroll_runs()` أو `admin_hr_payroll_run()`.
class HrPayrollRun {
  const HrPayrollRun({
    required this.runId,
    required this.periodYear,
    required this.periodMonth,
    required this.status,
    required this.statementCount,
    required this.totalGross,
    required this.totalDeductions,
    required this.totalNet,
    required this.calculatedAt,
    required this.approvedAt,
    required this.paidAt,
    required this.note,
    required this.scope,
    this.statements = const <HrPayrollStatement>[],
  });

  final String runId;
  final int periodYear;
  final int periodMonth;

  /// `draft|calculated|approved|paid|cancelled` — انتقالها يحرسه trigger.
  final String status;
  final int statementCount;
  final double totalGross;
  final double totalDeductions;
  final double totalNet;
  final DateTime? calculatedAt;
  final DateTime? approvedAt;
  final DateTime? paidAt;
  final String note;

  /// `brand` لمن يملك كل الفروع، و`branches` لمن يقرأ نطاقه فقط.
  final String scope;
  final List<HrPayrollStatement> statements;

  bool get isCalculated => status == 'calculated';
  bool get isApproved => status == 'approved';
  bool get isPaid => status == 'paid';
  bool get isCancellable => status == 'draft' || status == 'calculated';

  /// هل كُتب هذا الصف فعلًا: لا دورة بلا قسيمات تُعرض كأرقام صفر.
  bool get isReal => runId.isNotEmpty;

  static const HrPayrollRun none = HrPayrollRun(
    runId: '',
    periodYear: 0,
    periodMonth: 0,
    status: '',
    statementCount: 0,
    totalGross: 0,
    totalDeductions: 0,
    totalNet: 0,
    calculatedAt: null,
    approvedAt: null,
    paidAt: null,
    note: '',
    scope: '',
  );

  factory HrPayrollRun.fromJson(Map<String, dynamic> json) => HrPayrollRun(
    runId: hrText(json['run_id']),
    periodYear: hrInt(json['period_year']),
    periodMonth: hrInt(json['period_month']),
    status: hrText(json['status']),
    statementCount: hrInt(json['statement_count']),
    totalGross: hrNum(json['total_gross']),
    totalDeductions: hrNum(json['total_deductions']),
    totalNet: hrNum(json['total_net']),
    calculatedAt: hrDate(json['calculated_at']),
    approvedAt: hrDate(json['approved_at']),
    paidAt: hrDate(json['paid_at']),
    note: hrText(json['note']),
    scope: hrText(json['scope']),
    statements: hrMaps(json['statements'])
        .map(HrPayrollStatement.fromJson)
        .toList(),
  );
}
