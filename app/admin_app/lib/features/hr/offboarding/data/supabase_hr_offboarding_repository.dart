import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';
import '../domain/offboarding_models.dart';
import '../domain/offboarding_repository.dart';

class SupabaseHrOffboardingRepository implements HrOffboardingRepository {
  SupabaseHrOffboardingRepository({this._client});

  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? SupabaseService.client;

  @override
  Future<List<HrOffboardingCase>> loadCases() async {
    final raw = await client.rpc('admin_hr_offboarding_cases');
    return _rows(raw).map(HrOffboardingCase.fromJson).toList(growable: false);
  }

  @override
  Future<List<HrOffboardingPerson>> loadPeople() async {
    final raw = await client.rpc('admin_hr_employees');
    return _rows(raw).map(HrOffboardingPerson.fromJson).toList(growable: false);
  }

  @override
  Future<HrOffboardingCase> startCase({
    required String staffId,
    DateTime? lastWorkingOn,
    String note = '',
  }) => _case('admin_hr_start_offboarding', {
    'p_staff_id': staffId,
    'p_last_working_on': _day(lastWorkingOn),
    'p_note': note,
  });

  @override
  Future<HrOffboardingCase> assignStep({
    required String caseId,
    required String code,
    String? ownerStaffId,
    DateTime? dueOn,
  }) => _case('admin_hr_assign_offboarding_step', {
    'p_case_id': caseId,
    'p_code': code,
    'p_owner_staff': ownerStaffId,
    'p_due_on': _day(dueOn),
  });

  @override
  Future<HrOffboardingCase> setStep({
    required String caseId,
    required String code,
    required String status,
    String note = '',
  }) => _case('admin_hr_set_offboarding_step', {
    'p_case_id': caseId,
    'p_code': code,
    'p_status': status,
    'p_note': note,
  });

  @override
  Future<HrOffboardingCase> cancelCase({
    required String caseId,
    String note = '',
  }) => _case('admin_hr_cancel_offboarding', {
    'p_case_id': caseId,
    'p_note': note,
  });

  @override
  Future<HrOffboardingCase> finalizeCase({
    required String caseId,
    required DateTime terminatedOn,
    required String settlementNote,
  }) => _case('admin_hr_finalize_offboarding', {
    'p_case_id': caseId,
    'p_terminated_on': _day(terminatedOn),
    'p_note': settlementNote,
  });

  @override
  Future<HrOffboardingCase> suspendAccess({
    required String caseId,
    String note = '',
  }) => _case('admin_hr_suspend_offboarding_access', {
    'p_case_id': caseId,
    'p_note': note,
  });

  Future<HrOffboardingCase> _case(
    String function,
    Map<String, dynamic> params,
  ) async => HrOffboardingCase.fromJson(
    _map(await client.rpc(function, params: params)),
  );

  List<Map<String, dynamic>> _rows(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList(growable: false)
      : const [];

  Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  String? _day(DateTime? date) => date == null
      ? null
      : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
