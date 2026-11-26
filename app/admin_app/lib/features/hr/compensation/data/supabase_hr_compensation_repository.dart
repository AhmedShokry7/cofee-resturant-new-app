import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_app/core/services/supabase_service.dart';

import '../domain/hr_compensation_repository.dart';

class SupabaseHrCompensationRepository implements HrCompensationRepository {
  SupabaseHrCompensationRepository({this._client});
  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? SupabaseService.client;

  @override
  Future<List<HrCompensationEmployee>> loadEmployees() async {
    final raw = await client.rpc(
      'admin_hr_employees',
      params: {
        'p_search': null,
        'p_branch_id': null,
        'p_status': null,
        'p_department': null,
      },
    );
    return _rows(raw)
        .map(HrCompensationEmployee.fromJson)
        .where((employee) => employee.staffId.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>?> loadEmployeeCompensation(String staffId) async {
    final raw = await client.rpc(
      'admin_hr_employee',
      params: {'p_staff_id': staffId},
    );
    final detail = raw is Map ? Map<String, dynamic>.from(raw) : null;
    final compensation = detail?['compensation'];
    return compensation is Map ? Map<String, dynamic>.from(compensation) : null;
  }

  @override
  Future<void> addCompensation({
    required String staffId,
    required double basicSalary,
    required double housingAllowance,
    required double transportAllowance,
    required double otherAllowance,
    required DateTime effectiveFrom,
    required String note,
  }) async {
    await client.rpc(
      'admin_hr_set_compensation',
      params: {
        'p_staff_id': staffId,
        'p_basic_salary': basicSalary,
        'p_housing_allowance': housingAllowance,
        'p_transport_allowance': transportAllowance,
        'p_other_allowance': otherAllowance,
        'p_effective_from': _day(effectiveFrom),
        'p_note': note,
      },
    );
  }

  static List<Map<String, dynamic>> _rows(Object? value) => value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : const [];

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
