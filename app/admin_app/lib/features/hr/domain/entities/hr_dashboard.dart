import 'package:admin_app/features/hr/domain/entities/hr_attendance.dart';
import 'package:admin_app/features/hr/domain/entities/hr_json.dart';

/// لوحة HR من `admin_hr_dashboard()`.
///
/// التفاف القاعدة على القاعدة: كل قسم null حين لا صلاحية لقراءته، ولا يُستبدل
/// بصفر. الصفر يعني «صفر فعلًا في النطاق»، وnull يعني «لا تعرف الشاشة»، وفرق
/// العرض بينهما هو ما يمنع لوحة تكذب بأرقام تبدو صحيحة.
class HrDashboard {
  const HrDashboard({
    required this.dayLocal,
    required this.timeZone,
    required this.permissions,
    required this.headcount,
    required this.todayAttendance,
    required this.pending,
    required this.finance,
    required this.payroll,
    required this.me,
  });

  /// `YYYY-MM-DD` في المنطقة التجارية، لا في ساعة الجهاز.
  final String dayLocal;

  /// المنطقة التجارية التي حسبت بها القاعدة كل طابع محلي.
  final String timeZone;

  final HrDashboardPermissions permissions;
  final HrHeadcount headcount;

  /// null لمن لا يقرأ الحضور.
  final HrTodayAttendance? todayAttendance;
  final HrPendingCounts pending;
  final HrFinanceSummary? finance;
  final HrPayrollSummary? payroll;
  final HrMySnapshot me;

  static HrDashboard? tryParse(Object? raw) =>
      raw is Map ? HrDashboard.fromJson(Map<String, dynamic>.from(raw)) : null;

  factory HrDashboard.fromJson(Map<String, dynamic> json) => HrDashboard(
    dayLocal: hrText(json['today']),
    timeZone: hrText(json['time_zone']),
    permissions: HrDashboardPermissions.fromJson(hrMap(json['permissions'])),
    headcount: HrHeadcount.fromJson(hrMap(json['headcount'])),
    todayAttendance: json['today_attendance'] == null
        ? null
        : HrTodayAttendance.fromJson(hrMap(json['today_attendance'])),
    pending: HrPendingCounts.fromJson(hrMap(json['pending'])),
    finance: json['finance'] == null
        ? null
        : HrFinanceSummary.fromJson(hrMap(json['finance'])),
    payroll: json['payroll'] == null
        ? null
        : HrPayrollSummary.fromJson(hrMap(json['payroll'])),
    me: HrMySnapshot.fromJson(hrMap(json['me'])),
  );
}

/// الأذونات التي قررتها القاعدة لهذا القارئ، فتبني عليها الشاشة أدواتها.
class HrDashboardPermissions {
  const HrDashboardPermissions({
    required this.hr,
    required this.attendance,
    required this.schedule,
    required this.leaveReview,
    required this.finance,
    required this.payroll,
    required this.compensation,
  });

  final bool hr;
  final bool attendance;
  final bool schedule;
  final bool leaveReview;
  final bool finance;
  final bool payroll;
  final bool compensation;

  static const HrDashboardPermissions none = HrDashboardPermissions(
    hr: false,
    attendance: false,
    schedule: false,
    leaveReview: false,
    finance: false,
    payroll: false,
    compensation: false,
  );

  factory HrDashboardPermissions.fromJson(Map<String, dynamic> json) =>
      HrDashboardPermissions(
        hr: hrBool(json['hr']),
        attendance: hrBool(json['attendance']),
        schedule: hrBool(json['schedule']),
        leaveReview: hrBool(json['leave_review']),
        finance: hrBool(json['finance']),
        payroll: hrBool(json['payroll']),
        compensation: hrBool(json['compensation']),
      );
}

/// عدد الموظفين بحسب حالة التوظيف، في نطاق الفروع المسموح.
class HrHeadcount {
  const HrHeadcount({
    required this.total,
    required this.active,
    required this.probation,
    required this.onLeave,
    required this.terminated,
  });

  final int total;
  final int active;
  final int probation;
  final int onLeave;
  final int terminated;

  static const HrHeadcount zero = HrHeadcount(
    total: 0,
    active: 0,
    probation: 0,
    onLeave: 0,
    terminated: 0,
  );

  factory HrHeadcount.fromJson(Map<String, dynamic> json) => HrHeadcount(
    total: hrInt(json['total']),
    active: hrInt(json['active']),
    probation: hrInt(json['probation']),
    onLeave: hrInt(json['on_leave']),
    terminated: hrInt(json['terminated']),
  );
}

/// حضور اليوم: كم كان الجدول، وكم حضر، وكم يتأخر.
class HrTodayAttendance {
  const HrTodayAttendance({
    required this.scheduled,
    required this.present,
    required this.open,
    required this.late,
    required this.onLeave,
  });

  final int scheduled;
  final int present;

  /// جلسات ما زالت مفتوحة (لم تُغلق بعد).
  final int open;
  final int late;
  final int onLeave;

  factory HrTodayAttendance.fromJson(Map<String, dynamic> json) =>
      HrTodayAttendance(
        scheduled: hrInt(json['scheduled']),
        present: hrInt(json['present']),
        open: hrInt(json['open']),
        late: hrInt(json['late']),
        onLeave: hrInt(json['on_leave']),
      );
}

/// ما ينتظر مراجعة. null = لا صلاحية للعدّ، لا صفر ولا غيب.
class HrPendingCounts {
  const HrPendingCounts({
    this.leaveRequests,
    this.attendanceCorrections,
    this.advances,
    this.adjustments,
    this.discrepancies,
  });

  final int? leaveRequests;
  final int? attendanceCorrections;
  final int? advances;
  final int? adjustments;

  /// فروقات الصندوق التي ما زالت `pending_review` في نطاق الفروع المسموح.
  final int? discrepancies;

  /// كم بابًا ينتظر فعلًا، للشارة أعلى اللوحة.
  int get total =>
      (leaveRequests ?? 0) +
      (attendanceCorrections ?? 0) +
      (advances ?? 0) +
      (adjustments ?? 0) +
      (discrepancies ?? 0);

  factory HrPendingCounts.fromJson(Map<String, dynamic> json) =>
      HrPendingCounts(
        leaveRequests: json['leave_requests'] == null
            ? null
            : hrInt(json['leave_requests']),
        attendanceCorrections: json['attendance_corrections'] == null
            ? null
            : hrInt(json['attendance_corrections']),
        advances: json['advances'] == null ? null : hrInt(json['advances']),
        adjustments: json['adjustments'] == null
            ? null
            : hrInt(json['adjustments']),
        discrepancies: json['discrepancies'] == null
            ? null
            : hrInt(json['discrepancies']),
      );
}

/// ملخص مال الموظفين لمن يملك النظر فيه.
class HrFinanceSummary {
  const HrFinanceSummary({
    this.openDiscrepancies,
    this.openDiscrepancyAmount,
    this.advancesOutstanding,
  });

  final int? openDiscrepancies;
  final double? openDiscrepancyAmount;

  /// مجموع ما صُرف من سلف ولم يُسترد بعد.
  final double? advancesOutstanding;

  factory HrFinanceSummary.fromJson(Map<String, dynamic> json) =>
      HrFinanceSummary(
        openDiscrepancies: json['open_discrepancies'] == null
            ? null
            : hrInt(json['open_discrepancies']),
        openDiscrepancyAmount: json['open_discrepancy_amount'] == null
            ? null
            : hrNum(json['open_discrepancy_amount']),
        advancesOutstanding: json['advances_outstanding'] == null
            ? null
            : hrNum(json['advances_outstanding']),
      );
}

/// دورة هذا الشهر كما تراها اللوحة؛ run null حين لا دورة بعد.
///
/// اللوحة ترسل من الدورة أربعة أرقام فقط، والحفظ هنا أربعة حقول بقدرها: لو مرّ
/// الردّ عبر `HrPayrollRun` لظهر `total_gross` صفرًا لم ترسله القاعدة قط.
class HrPayrollSummary {
  const HrPayrollSummary({
    required this.periodYear,
    required this.periodMonth,
    this.run,
  });

  final int periodYear;
  final int periodMonth;
  final HrDashboardRun? run;

  factory HrPayrollSummary.fromJson(Map<String, dynamic> json) =>
      HrPayrollSummary(
        periodYear: hrInt(json['period_year']),
        periodMonth: hrInt(json['period_month']),
        run: json['run'] == null
            ? null
            : HrDashboardRun.fromJson(hrMap(json['run'])),
      );
}

/// مختصر دورة الرواتب داخل اللوحة، بأربعة أرقام لا غير.
class HrDashboardRun {
  const HrDashboardRun({
    required this.runId,
    required this.status,
    required this.totalNet,
    required this.statementCount,
  });

  final String runId;

  /// `draft|calculated|approved|paid|cancelled` — أو فارغًا إن لم توجد دورة.
  final String status;
  final double? totalNet;
  final int statementCount;

  /// الصف موجود فعلًا؛ عدّ هذا قبل عرض أي رقم.
  bool get isReal => runId.isNotEmpty;

  factory HrDashboardRun.fromJson(Map<String, dynamic> json) => HrDashboardRun(
    runId: hrText(json['run_id']),
    status: hrText(json['status']),
    // `total_net` نفسه null حين لا دورة، فالتفريق بينهما لا يُقرأ صفرًا.
    totalNet: json['total_net'] == null ? null : hrNum(json['total_net']),
    statementCount: hrInt(json['statement_count']),
  );
}

/// موضع الموظف نفسه من اللوحة: جلسته المفتوحة وأجره الأخير.
class HrMySnapshot {
  const HrMySnapshot({
    required this.staffId,
    required this.openSession,
    required this.workedMinutesToday,
    required this.pendingLeave,
    required this.openAdvances,
    required this.latestPayslip,
  });

  final String staffId;

  /// الجلسة المفتوحة للمستخدم نفسه، لتُعرض أزرار التوقيت عنده.
  final HrAttendanceSession? openSession;
  final int workedMinutesToday;
  final int pendingLeave;

  /// عدد الطلبات التي ما زالت معلّقة أو معتمدة قبل الصرف؛ تترجمها الشارة إلى
  /// «نعم/لا»، والعدّ نفسه لا يُختزل في boolean فتفقد الشاشة معلومة.
  final int openAdvances;
  final HrPayslipBrief? latestPayslip;

  bool get hasOpenAdvance => openAdvances > 0;

  static const HrMySnapshot empty = HrMySnapshot(
    staffId: '',
    openSession: null,
    workedMinutesToday: 0,
    pendingLeave: 0,
    openAdvances: 0,
    latestPayslip: null,
  );

  factory HrMySnapshot.fromJson(Map<String, dynamic> json) => HrMySnapshot(
    staffId: hrText(json['staff_id']),
    openSession: json['open_session'] == null
        ? null
        : HrAttendanceSession.fromJson(hrMap(json['open_session'])),
    workedMinutesToday: hrInt(json['worked_minutes_today']),
    pendingLeave: hrInt(json['pending_leave']),
    openAdvances: hrInt(json['open_advance']),
    latestPayslip: json['latest_payslip'] == null
        ? null
        : HrPayslipBrief.fromJson(hrMap(json['latest_payslip'])),
  );
}

/// آخر قسيمة معتمدة أو مدفوعة، كما تسمّيها `me.latest_payslip`.
class HrPayslipBrief {
  const HrPayslipBrief({
    required this.statementId,
    required this.periodYear,
    required this.periodMonth,
    required this.net,
    required this.currencyCode,
  });

  final String statementId;
  final int periodYear;
  final int periodMonth;
  final double net;
  final String currencyCode;

  factory HrPayslipBrief.fromJson(Map<String, dynamic> json) => HrPayslipBrief(
    statementId: hrText(json['statement_id']),
    periodYear: hrInt(json['period_year']),
    periodMonth: hrInt(json['period_month']),
    net: hrNum(json['net']),
    currencyCode: hrText(json['currency_code']),
  );
}
