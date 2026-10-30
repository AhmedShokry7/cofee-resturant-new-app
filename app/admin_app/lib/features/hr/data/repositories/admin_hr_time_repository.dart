import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/hr/data/hr_rpc.dart';
import 'package:admin_app/features/hr/domain/entities/hr_attendance.dart';
import 'package:admin_app/features/hr/domain/entities/hr_json.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/entities/hr_schedule.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_time_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// تنفيذ عقد الحضور والجدول على الأقسام 15–17 من التهيئة 212.
///
/// البصائر كلها بأوقات القاعدة: لا يرسل العميل ساعة جهازه، ولا تحسب الشاشة
/// دقائق التأخير — فهذان يكتبهما `hr.attendance_sessions` و`hr.settings`.
class AdminHrTimeRepository implements HrTimeRepository {
  AdminHrTimeRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<HrAttendanceSession> clockIn({
    required String branchId,
    String? note,
  }) => _session('hr_clock_in', <String, dynamic>{
    'p_branch_id': branchId,
    'p_note': note,
  });

  @override
  Future<HrAttendanceSession> clockOut({String? note}) =>
      _session('hr_clock_out', <String, dynamic>{'p_note': note});

  @override
  Future<HrAttendanceSession> breakStart() => _session('hr_break_start');

  @override
  Future<HrAttendanceSession> breakEnd() => _session('hr_break_end');

  @override
  Future<HrMyAttendance> loadMyAttendance({
    DateTime? from,
    DateTime? to,
  }) async {
    return HrMyAttendance.fromJson(
      await HrRpc.object(
        _supabase,
        'hr_my_attendance',
        params: <String, dynamic>{
          'p_from': HrRpc.day(from),
          'p_to': HrRpc.day(to),
        },
      ),
    );
  }

  @override
  Future<List<HrAttendanceRow>> loadAttendance({
    required DateTime from,
    required DateTime to,
    String? branchId,
    String? staffId,
  }) async {
    final rows = await HrRpc.rows(
      _supabase,
      'admin_hr_attendance',
      params: <String, dynamic>{
        'p_from': HrRpc.day(from),
        'p_to': HrRpc.day(to),
        'p_branch_id': branchId,
        'p_staff_id': staffId,
      },
    );
    return rows.map(HrAttendanceRow.fromJson).toList();
  }

  @override
  Future<HrReceipt> requestCorrection({
    required String staffId,
    String? sessionId,
    DateTime? clockInAt,
    DateTime? clockOutAt,
    required String reason,
  }) async {
    return HrReceipt.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_request_attendance_correction',
        params: <String, dynamic>{
          'p_staff_id': staffId,
          'p_session_id': sessionId,
          'p_clock_in': HrRpc.instant(clockInAt),
          'p_clock_out': HrRpc.instant(clockOutAt),
          'p_reason': reason,
        },
      ),
    );
  }

  @override
  Future<List<HrAttendanceCorrection>> loadCorrections({String? status}) async {
    final rows = await HrRpc.rows(
      _supabase,
      'admin_hr_attendance_corrections',
      params: <String, dynamic>{'p_status': status},
    );
    return rows.map(HrAttendanceCorrection.fromJson).toList();
  }

  @override
  Future<HrAttendanceSession?> reviewCorrection({
    required String correctionId,
    required bool approve,
    String? note,
  }) async {
    final response = await HrRpc.object(
      _supabase,
      'admin_hr_review_attendance_correction',
      params: <String, dynamic>{
        'p_correction_id': correctionId,
        'p_approve': approve,
        'p_note': note,
      },
    );
    // الرفض يجيب `{id, status}` وحده، فلا جلسة تُقرأ ولا صفحة تُعرض.
    final session = response['session'];
    return session == null
        ? null
        : HrAttendanceSession.fromJson(hrMap(session));
  }

  @override
  Future<List<HrWorkSchedule>> loadSchedules({
    required DateTime from,
    required DateTime to,
    String? branchId,
    String? staffId,
  }) async {
    final rows = await HrRpc.rows(
      _supabase,
      'admin_hr_schedules',
      params: <String, dynamic>{
        'p_from': HrRpc.day(from),
        'p_to': HrRpc.day(to),
        'p_branch_id': branchId,
        'p_staff_id': staffId,
      },
    );
    return rows.map(HrWorkSchedule.fromJson).toList();
  }

  @override
  Future<HrWorkSchedule> saveSchedule({
    required String staffId,
    required String branchId,
    required DateTime start,
    required DateTime end,
    int breakMinutes = 0,
    String status = 'draft',
    String? note,
    String? id,
  }) async {
    return HrWorkSchedule.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_save_schedule',
        params: <String, dynamic>{
          'p_id': id,
          'p_staff_id': staffId,
          'p_branch_id': branchId,
          'p_start': HrRpc.instant(start),
          'p_end': HrRpc.instant(end),
          'p_break_minutes': breakMinutes,
          'p_status': status,
          'p_note': note,
        },
      ),
    );
  }

  @override
  Future<HrReceipt> setScheduleStatus({
    required String id,
    required String status,
  }) async {
    return HrReceipt.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_set_schedule_status',
        params: <String, dynamic>{'p_id': id, 'p_status': status},
      ),
    );
  }

  Future<HrAttendanceSession> _session(
    String function, [
    Map<String, dynamic>? params,
  ]) async {
    return HrAttendanceSession.fromJson(
      await HrRpc.object(_supabase, function, params: params),
    );
  }
}
