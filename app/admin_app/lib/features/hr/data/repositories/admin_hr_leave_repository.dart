import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/hr/data/hr_rpc.dart';
import 'package:admin_app/features/hr/domain/entities/hr_leave.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_leave_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// تنفيذ عقد الإجازات على القسم 17 من التهيئة 212.
///
/// الطلب لا يحمل `p_staff_id`: القاعدة تقرأه من الجلسة، فلا يستطيع مدير أن
/// يفتعل إجازة باسم موظف لم يطلبها.
class AdminHrLeaveRepository implements HrLeaveRepository {
  AdminHrLeaveRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<HrReceipt> requestLeave({
    required String leaveTypeId,
    required DateTime startsOn,
    required DateTime endsOn,
    String? reason,
    String? supportingDocument,
  }) async {
    return HrReceipt.fromJson(
      await HrRpc.object(
        _supabase,
        'hr_request_leave',
        params: <String, dynamic>{
          'p_leave_type_id': leaveTypeId,
          'p_starts_on': HrRpc.day(startsOn),
          'p_ends_on': HrRpc.day(endsOn),
          'p_reason': reason,
          'p_supporting_document': supportingDocument,
        },
      ),
    );
  }

  @override
  Future<HrReceipt> cancelRequest({
    required String requestId,
    String? note,
  }) async {
    return HrReceipt.fromJson(
      await HrRpc.object(
        _supabase,
        'hr_cancel_leave_request',
        params: <String, dynamic>{'p_request_id': requestId, 'p_note': note},
      ),
    );
  }

  @override
  Future<List<HrLeaveRequest>> loadRequests({
    String? status,
    String? staffId,
  }) async {
    final rows = await HrRpc.rows(
      _supabase,
      'admin_hr_leave_requests',
      params: <String, dynamic>{'p_status': status, 'p_staff_id': staffId},
    );
    return rows.map(HrLeaveRequest.fromJson).toList();
  }

  @override
  Future<HrReceipt> reviewRequest({
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    return HrReceipt.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_review_leave',
        params: <String, dynamic>{
          'p_request_id': requestId,
          'p_approve': approve,
          'p_note': note,
        },
      ),
    );
  }

  @override
  Future<HrLeaveBalance> setBalance({
    required String staffId,
    required String leaveTypeId,
    required int year,
    required double entitledDays,
  }) async {
    return HrLeaveBalance.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_set_leave_balance',
        params: <String, dynamic>{
          'p_staff_id': staffId,
          'p_leave_type_id': leaveTypeId,
          'p_year': year,
          'p_entitled_days': entitledDays,
        },
      ),
    );
  }
}
