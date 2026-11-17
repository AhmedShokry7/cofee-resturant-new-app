import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_app/core/services/supabase_service.dart';

import '../../domain/models/hr_leave_models.dart';
import '../../domain/repositories/hr_leave_repository.dart';

class SupabaseHrLeaveRepository implements HrLeaveRepository {
  SupabaseHrLeaveRepository({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? SupabaseService.client;

  @override
  Future<List<HrLeaveType>> loadTypes() async {
    final raw = await client.rpc('admin_hr_reference');
    if (raw is! Map || raw['leave_types'] is! List) return const [];
    return (raw['leave_types'] as List)
        .whereType<Map>()
        .map((row) => HrLeaveType.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<List<HrLeaveRequest>> loadRequests({String? status}) async {
    final raw = await client.rpc(
      'admin_hr_leave_requests',
      params: {'p_status': status, 'p_staff_id': null},
    );
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) => HrLeaveRequest.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<void> reviewRequest({
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    await client.rpc(
      'admin_hr_review_leave',
      params: {'p_request_id': requestId, 'p_approve': approve, 'p_note': note},
    );
  }

  @override
  Future<void> setBalance({
    required String staffId,
    required String leaveTypeId,
    required int year,
    required double entitledDays,
  }) async {
    await client.rpc(
      'admin_hr_set_leave_balance',
      params: {
        'p_staff_id': staffId,
        'p_leave_type_id': leaveTypeId,
        'p_year': year,
        'p_entitled_days': entitledDays,
      },
    );
  }

  @override
  Future<void> saveType(HrLeaveType type, {bool create = false}) async {
    await client.rpc(
      'admin_hr_save_leave_type',
      params: {
        'p_id': create ? null : type.id,
        'p_code': create ? type.code : null,
        'p_name_ar': type.nameAr,
        'p_name_en': type.nameEn,
        'p_requires_document': type.requiresDocument,
        'p_is_paid': type.isPaid,
        'p_tracks_balance': type.tracksBalance,
        'p_default_annual_days': type.defaultAnnualDays,
        'p_is_active': type.isActive,
      },
    );
  }
}
