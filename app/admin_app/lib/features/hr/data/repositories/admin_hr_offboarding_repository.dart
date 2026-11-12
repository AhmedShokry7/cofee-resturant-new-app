import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/hr/data/hr_rpc.dart';
import 'package:admin_app/features/hr/domain/entities/hr_offboarding.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_offboarding_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// تنفيذ عقد إنهاء الخدمة على RPCs المهاجرة 241.
///
/// القراءة والكتابة لا تمرّان إلا من `admin_hr_offboarding_*`، والرفض يتحول
/// مرة واحدة إلى `HrRefusal` في `HrRpc` كما في بقية HR.
class AdminHrOffboardingRepository implements HrOffboardingRepository {
  AdminHrOffboardingRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  @override
  Future<List<HrOffboardingCase>> loadCases({String? staffId}) async {
    final rows = await HrRpc.rows(
      _supabase,
      'admin_hr_offboarding_cases',
      params: <String, dynamic>{'p_staff_id': staffId},
    );
    return rows.map(HrOffboardingCase.fromJson).toList();
  }

  @override
  Future<HrOffboardingCase> start({
    required String staffId,
    DateTime? lastWorkingOn,
    String? note,
  }) async {
    return HrOffboardingCase.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_start_offboarding',
        params: <String, dynamic>{
          'p_staff_id': staffId,
          'p_last_working_on': HrRpc.day(lastWorkingOn),
          'p_note': note,
        },
      ),
    );
  }

  @override
  Future<HrOffboardingCase> assignStep({
    required String caseId,
    required String code,
    String? ownerStaffId,
    DateTime? dueOn,
  }) async {
    return HrOffboardingCase.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_assign_offboarding_step',
        params: <String, dynamic>{
          'p_case_id': caseId,
          'p_code': code,
          'p_owner_staff': ownerStaffId,
          'p_due_on': HrRpc.day(dueOn),
        },
      ),
    );
  }

  @override
  Future<HrOffboardingCase> setStep({
    required String caseId,
    required String code,
    required String status,
    String? note,
  }) async {
    return HrOffboardingCase.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_set_offboarding_step',
        params: <String, dynamic>{
          'p_case_id': caseId,
          'p_code': code,
          'p_status': status,
          'p_note': note,
        },
      ),
    );
  }

  @override
  Future<HrOffboardingCase> cancel({
    required String caseId,
    String? note,
  }) async {
    return HrOffboardingCase.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_cancel_offboarding',
        params: <String, dynamic>{'p_case_id': caseId, 'p_note': note},
      ),
    );
  }

  @override
  Future<HrOffboardingCase> finalize({
    required String caseId,
    DateTime? terminatedOn,
    String? note,
  }) async {
    return HrOffboardingCase.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_finalize_offboarding',
        params: <String, dynamic>{
          'p_case_id': caseId,
          'p_terminated_on': HrRpc.day(terminatedOn),
          'p_note': note,
        },
      ),
    );
  }

  @override
  Future<HrOffboardingCase> suspendAccess({
    required String caseId,
    String? note,
  }) async {
    return HrOffboardingCase.fromJson(
      await HrRpc.object(
        _supabase,
        'admin_hr_suspend_offboarding_access',
        params: <String, dynamic>{'p_case_id': caseId, 'p_note': note},
      ),
    );
  }
}
