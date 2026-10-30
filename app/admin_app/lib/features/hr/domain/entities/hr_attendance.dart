import 'package:admin_app/features/hr/domain/entities/hr_json.dart';

/// جلسة حضور كما ترسلها `hr.attendance_json`: بصائر ساعة القاعدة.
///
/// `clock_in` بالحسابة العالمي و`clock_in_local` نص المنطقة التجارية الذي
/// حسبته `hr.fmt_ts`. تعرض الشاشات المحلي دائمًا، لأن ساعة الجهاز لا شاهد على
/// شيء: من يحرّك ساعة laptopه يحرّك شاشة، لا صفّ القاعدة.
class HrAttendanceSession {
  const HrAttendanceSession({
    required this.id,
    required this.staffId,
    required this.branchId,
    required this.branchName,
    required this.clockIn,
    required this.clockOut,
    required this.clockInLocal,
    required this.clockOutLocal,
    required this.breakStartedAt,
    required this.breakEndedAt,
    required this.isOpen,
    required this.isOnBreak,
    required this.workedMinutes,
    required this.note,
    required this.clockOutNote,
  });

  final String id;
  final String staffId;
  final String branchId;
  final String branchName;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final String clockInLocal;
  final String clockOutLocal;

  /// الراحة الواحدة لكل جلسة: تفتح مرة وتُغلق، ولا ثانية بعد الثانية.
  final DateTime? breakStartedAt;
  final DateTime? breakEndedAt;
  final bool isOpen;
  final bool isOnBreak;

  /// الدقائق كما نقصتها القاعدة من زمن الراحة، لا من تقدير الواجهة.
  final int workedMinutes;
  final String note;
  final String clockOutNote;

  static const HrAttendanceSession none = HrAttendanceSession(
    id: '',
    staffId: '',
    branchId: '',
    branchName: '',
    clockIn: null,
    clockOut: null,
    clockInLocal: '',
    clockOutLocal: '',
    breakStartedAt: null,
    breakEndedAt: null,
    isOpen: false,
    isOnBreak: false,
    workedMinutes: 0,
    note: '',
    clockOutNote: '',
  );

  bool get isReal => id.isNotEmpty;

  factory HrAttendanceSession.fromJson(Map<String, dynamic> json) =>
      HrAttendanceSession(
        id: hrText(json['id']),
        staffId: hrText(json['staff_id']),
        branchId: hrText(json['branch_id']),
        branchName: hrText(json['branch_name_ar']).isEmpty
            ? hrText(json['branch_name_en'])
            : hrText(json['branch_name_ar']),
        clockIn: hrDate(json['clock_in']),
        clockOut: hrDate(json['clock_out']),
        clockInLocal: hrText(json['clock_in_local']),
        clockOutLocal: hrText(json['clock_out_local']),
        breakStartedAt: hrDate(json['break_started_at']),
        breakEndedAt: hrDate(json['break_ended_at']),
        isOpen: hrBool(json['is_open']),
        // اللوحة تسمّي علامة الراحة `on_break` والجلسة تسمّيها `is_on_break`:
        // قراءتهما معًا تُبقي زر «نهاية الراحة» صوابًا في المصدرين.
        isOnBreak: hrBool(json['is_on_break']) || hrBool(json['on_break']),
        workedMinutes: hrInt(json['worked_minutes']),
        note: hrText(json['note']),
        clockOutNote: hrText(json['clock_out_note']),
      );
}

/// صف اليوم في جدول الحضور من `admin_hr_attendance()`.
///
/// `late_minutes` و`early_minutes` تحسبهما القاعدة مقابل الجدول المنشور بعد
/// سعة التأخير في `hr.settings`، فالشاشة لا تعرف لا الجدول ولا السعة.
class HrAttendanceRow {
  const HrAttendanceRow({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.branchId,
    required this.branchName,
    required this.dayLocal,
    required this.clockInLocal,
    required this.clockOutLocal,
    required this.isOpen,
    required this.isMissingClockOut,
    required this.workedMinutes,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.lateMinutes,
    required this.earlyMinutes,
  });

  final String id;
  final String staffId;
  final String staffName;
  final String branchId;
  final String branchName;

  /// اليوم بالتاريخ المحلي للمنطقة التجارية،YYYY-MM-DD.
  final String dayLocal;
  final String clockInLocal;
  final String clockOutLocal;
  final bool isOpen;

  /// الجلسة التي لم تُغلق بعد ست عشرة ساعة: علامة القاعدة لا ساعة الشاشة.
  final bool isMissingClockOut;
  final int workedMinutes;

  /// فارغان حين لا جدول منشور لذلك اليوم، فلا تأخير يُنسب لموظف بلا ميعاد.
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final int lateMinutes;
  final int earlyMinutes;

  bool get hasSchedule => scheduledStart != null;

  factory HrAttendanceRow.fromJson(Map<String, dynamic> json) =>
      HrAttendanceRow(
        id: hrText(json['id']),
        staffId: hrText(json['staff_id']),
        staffName: hrText(json['staff_name']),
        branchId: hrText(json['branch_id']),
        branchName: hrText(json['branch_name_ar']).isEmpty
            ? hrText(json['branch_name_en'])
            : hrText(json['branch_name_ar']),
        dayLocal: hrText(json['date_local']),
        clockInLocal: hrText(json['clock_in_local']),
        clockOutLocal: hrText(json['clock_out_local']),
        isOpen: hrBool(json['is_open']),
        isMissingClockOut: hrBool(json['is_missing_clock_out']),
        workedMinutes: hrInt(json['worked_minutes']),
        scheduledStart: hrDate(json['scheduled_start']),
        scheduledEnd: hrDate(json['scheduled_end']),
        lateMinutes: hrInt(json['late_minutes']),
        earlyMinutes: hrInt(json['early_minutes']),
      );
}

/// تصحيح حضور معلّق أو محسوم، من `admin_hr_attendance_corrections()`.
class HrAttendanceCorrection {
  const HrAttendanceCorrection({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.branchName,
    required this.sessionId,
    required this.currentClockInLocal,
    required this.currentClockOutLocal,
    required this.proposedClockInLocal,
    required this.proposedClockOutLocal,
    required this.reason,
    required this.status,
    required this.requestedByName,
    required this.reviewedByName,
    required this.reviewedAt,
    required this.reviewNote,
    required this.createdAtLocal,
  });

  final String id;
  final String staffId;
  final String staffName;
  final String branchName;

  /// null = التصحيح يسجل جلسة جديدة لا تعديل جلسة قائمة.
  final String? sessionId;
  final String currentClockInLocal;
  final String currentClockOutLocal;
  final String proposedClockInLocal;
  final String proposedClockOutLocal;
  final String reason;

  /// `pending|approved|rejected|cancelled`.
  final String status;
  final String requestedByName;
  final String reviewedByName;
  final DateTime? reviewedAt;
  final String reviewNote;
  final String createdAtLocal;

  bool get isPending => status == 'pending';

  factory HrAttendanceCorrection.fromJson(Map<String, dynamic> json) =>
      HrAttendanceCorrection(
        id: hrText(json['id']),
        staffId: hrText(json['staff_id']),
        staffName: hrText(json['staff_name']),
        branchName: hrText(json['branch_name_ar']).isEmpty
            ? hrText(json['branch_name_en'])
            : hrText(json['branch_name_ar']),
        sessionId: hrId(json['session_id']),
        currentClockInLocal: hrText(json['current_clock_in_local']),
        currentClockOutLocal: hrText(json['current_clock_out_local']),
        proposedClockInLocal: hrText(json['proposed_clock_in_local']),
        proposedClockOutLocal: hrText(json['proposed_clock_out_local']),
        reason: hrText(json['reason']),
        status: hrText(json['status']),
        requestedByName: hrText(json['requested_by_name']),
        reviewedByName: hrText(json['reviewed_by_name']),
        reviewedAt: hrDate(json['reviewed_at']),
        reviewNote: hrText(json['review_note']),
        createdAtLocal: hrText(json['created_at_local']),
      );
}

/// مجموع أيام الحضور في `hr_my_attendance()`، وكلّه من القاعدة.
class HrAttendanceMetrics {
  const HrAttendanceMetrics({
    required this.scheduledShifts,
    required this.scheduledMinutes,
    required this.absenceDays,
    required this.lateMinutes,
    required this.earlyMinutes,
    required this.workedMinutes,
    required this.presentShifts,
  });

  final int scheduledShifts;
  final int scheduledMinutes;
  final int absenceDays;
  final int lateMinutes;
  final int earlyMinutes;
  final int workedMinutes;
  final int presentShifts;

  static const HrAttendanceMetrics zero = HrAttendanceMetrics(
    scheduledShifts: 0,
    scheduledMinutes: 0,
    absenceDays: 0,
    lateMinutes: 0,
    earlyMinutes: 0,
    workedMinutes: 0,
    presentShifts: 0,
  );

  factory HrAttendanceMetrics.fromJson(Map<String, dynamic> json) =>
      HrAttendanceMetrics(
        scheduledShifts: hrInt(json['scheduled_shifts']),
        scheduledMinutes: hrInt(json['scheduled_minutes']),
        absenceDays: hrInt(json['absence_days']),
        lateMinutes: hrInt(json['late_minutes']),
        earlyMinutes: hrInt(json['early_minutes']),
        workedMinutes: hrInt(json['worked_minutes']),
        presentShifts: hrInt(json['present_shifts']),
      );
}

/// صفحة «حاضري» للموظف نفسه: جلسته المفتوحة وأيامه ومجاميعه.
class HrMyAttendance {
  const HrMyAttendance({
    required this.staffId,
    required this.openSession,
    required this.sessions,
    required this.metrics,
  });

  final String staffId;

  /// الجلسة المفتوحة الآن إن وُجدت، وهي التي تحدد أي الأزرار يُضغط.
  final HrAttendanceSession? openSession;
  final List<HrAttendanceSession> sessions;
  final HrAttendanceMetrics metrics;

  static const HrMyAttendance empty = HrMyAttendance(
    staffId: '',
    openSession: null,
    sessions: <HrAttendanceSession>[],
    metrics: HrAttendanceMetrics.zero,
  );

  factory HrMyAttendance.fromJson(Map<String, dynamic> json) => HrMyAttendance(
    staffId: hrText(json['staff_id']),
    openSession: json['open_session'] == null
        ? null
        : HrAttendanceSession.fromJson(hrMap(json['open_session'])),
    sessions: hrMaps(json['sessions'])
        .map(HrAttendanceSession.fromJson)
        .toList(),
    metrics: HrAttendanceMetrics.fromJson(hrMap(json['metrics'])),
  );
}
