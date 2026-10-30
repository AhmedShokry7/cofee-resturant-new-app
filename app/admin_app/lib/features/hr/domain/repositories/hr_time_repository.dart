import 'package:admin_app/features/hr/domain/entities/hr_attendance.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/entities/hr_schedule.dart';

/// عقد الحضور والجدول: ما يفعله الموظف بنفسه، وما يراجعه المدير.
abstract interface class HrTimeRepository {
  /// بصمة دخول الموظف نفسه، بساعة القاعدة وزمن فرع نشط يديره.
  Future<HrAttendanceSession> clockIn({required String branchId, String? note});

  Future<HrAttendanceSession> clockOut({String? note});

  Future<HrAttendanceSession> breakStart();

  Future<HrAttendanceSession> breakEnd();

  /// أيام الموظف نفسه ومجاميعه في مدى لا يتجاوز 92 يومًا.
  Future<HrMyAttendance> loadMyAttendance({DateTime? from, DateTime? to});

  /// جدول الحضور الإداري في مدى يومين على الأكثر 92 يومًا.
  Future<List<HrAttendanceRow>> loadAttendance({
    required DateTime from,
    required DateTime to,
    String? branchId,
    String? staffId,
  });

  /// فتح اعتراض. لا يتغيّر أي صف قبل المراجعة، لذا الإيصال لا يدّعي تصحيحًا.
  Future<HrReceipt> requestCorrection({
    required String staffId,
    String? sessionId,
    DateTime? clockInAt,
    DateTime? clockOutAt,
    required String reason,
  });

  Future<List<HrAttendanceCorrection>> loadCorrections({String? status});

  /// قرار المراجعة: الاعتماد يكتب الجلسة ويعيدها في `session`، والرفض يتركها.
  Future<HrAttendanceSession?> reviewCorrection({
    required String correctionId,
    required bool approve,
    String? note,
  });

  Future<List<HrWorkSchedule>> loadSchedules({
    required DateTime from,
    required DateTime to,
    String? branchId,
    String? staffId,
  });

  /// إنشاء أو تعديل وردية عمل؛ `id` null تنشئ، وغيرها يعدل كل الأعمدة.
  Future<HrWorkSchedule> saveSchedule({
    required String staffId,
    required String branchId,
    required DateTime start,
    required DateTime end,
    int breakMinutes = 0,
    String status = 'draft',
    String? note,
    String? id,
  });

  /// الإلغاء من هنا لا من `saveSchedule`، التي لا تقبل إلا draft أو published.
  Future<HrReceipt> setScheduleStatus({
    required String id,
    required String status,
  });
}
