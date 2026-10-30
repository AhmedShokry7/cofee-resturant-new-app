import 'package:admin_app/features/hr/domain/entities/hr_attendance.dart';
import 'package:admin_app/features/hr/domain/entities/hr_leave.dart';
import 'package:admin_app/features/hr/domain/entities/hr_payroll.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';

/// حالة شاشة «يومي»: بصمتي الحاضرة، لا سجل غيري.
class HrMyDayState {
  const HrMyDayState({
    this.status = HrLoadStatus.initial,
    this.reference,
    this.attendance = HrMyAttendance.empty,
    this.payslips,
    this.leaves,
    this.failure,
    this.writing = HrWriteStatus.idle,
    this.lastSession,
  });

  final HrLoadStatus status;

  /// الفروع التي يصح أن أبصم فيها، وأنواع الإجازة، وسياسة العمل. `null` ما لم
  /// تعد بعد، فلا تُبنى الأزرار على قائمة لم تُقرأ.
  final HrReference? reference;
  final HrMyAttendance attendance;

  /// `null` لم تُقرأ بعد أو رُفضت: الصفر هنا ليس «لا قسائم».
  final List<HrPayrollStatement>? payslips;
  final List<HrLeaveRequest>? leaves;

  /// رفض القاعدة الأخير، يُعرض بحروفها لا بـ«حدث خطأ».
  final HrRefusal? failure;

  final HrWriteStatus writing;

  /// آخر جلسة عادت من بصمة، لتُحدَّث البطاقة بها دون إعادة تحميل كامل.
  final HrAttendanceSession? lastSession;

  bool get isLoading => status == HrLoadStatus.loading;
  bool get isWriting => writing == HrWriteStatus.sending;
  bool get canClock => (reference?.myStaffId ?? '').isNotEmpty;

  /// الجلسة المفتوحة: آخر بصمة إن كانت ما زالت مفتوحة، وإلا ما رُدم من سجلّي.
  ///
  /// بصمة الانصراف ترجع جلستها وقد انطبقت، فلو قدّمتها على السجل لظلت البطاقة
  /// تعرض «منذ» وزرّ انصراف بعد أن أُغلق السطر، والثانية ترفضها القاعدة.
  HrAttendanceSession? get openSession {
    final last = lastSession;
    if (last != null && last.isOpen) return last;
    return attendance.openSession;
  }

  HrMyDayState copyWith({
    HrLoadStatus? status,
    HrReference? reference,
    HrMyAttendance? attendance,
    List<HrPayrollStatement>? payslips,
    List<HrLeaveRequest>? leaves,
    HrRefusal? failure,
    bool clearFailure = false,
    HrWriteStatus? writing,
    HrAttendanceSession? lastSession,
  }) => HrMyDayState(
    status: status ?? this.status,
    reference: reference ?? this.reference,
    attendance: attendance ?? this.attendance,
    payslips: payslips ?? this.payslips,
    leaves: leaves ?? this.leaves,
    failure: clearFailure ? null : (failure ?? this.failure),
    writing: writing ?? this.writing,
    lastSession: lastSession ?? this.lastSession,
  );
}
