import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_app/core/services/supabase_service.dart';

import '../domain/hr_schedule.dart';
import '../domain/hr_schedule_repository.dart';

class SupabaseHrScheduleRepository implements HrScheduleRepository {
  SupabaseHrScheduleRepository({this._client});
  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? SupabaseService.client;

  @override
  Future<(List<HrScheduleBranch>, List<HrScheduleEmployee>)> loadReference({
    required bool canReadEmployees,
  }) async {
    final raw = await client.rpc('admin_hr_reference');
    final reference = _asMap(raw);
    final branches = _rows(reference['branches'])
        .map(HrScheduleBranch.fromJson)
        .where((e) => e.id.isNotEmpty)
        .toList(growable: false);
    final employees = canReadEmployees
        ? _rows(
            await client.rpc(
              'admin_hr_employees',
              params: {
                'p_search': null,
                'p_branch_id': null,
                'p_status': null,
                'p_department': null,
              },
            ),
          ).map(HrScheduleEmployee.fromJson).toList(growable: false)
        : const <HrScheduleEmployee>[];
    return (branches, employees);
  }

  @override
  Future<List<HrSchedule>> loadSchedules({
    required DateTime from,
    required DateTime to,
    String? branchId,
  }) async => _rows(
    await client.rpc(
      'admin_hr_schedules',
      params: {
        'p_from': _day(from),
        'p_to': _day(to),
        'p_branch_id': branchId,
        'p_staff_id': null,
      },
    ),
  ).map(HrSchedule.fromJson).toList(growable: false);

  @override
  Future<void> saveSchedule({
    required String staffId,
    required String branchId,
    required DateTime start,
    required DateTime end,
    required int breakMinutes,
    required String status,
    required String note,
    String? id,
  }) async {
    await client.rpc(
      'admin_hr_save_schedule',
      params: {
        'p_staff_id': staffId,
        'p_branch_id': branchId,
        'p_start': start.toUtc().toIso8601String(),
        'p_end': end.toUtc().toIso8601String(),
        'p_break_minutes': breakMinutes,
        'p_status': status,
        'p_note': note,
        'p_id': id,
      },
    );
  }

  @override
  Future<void> setStatus(String id, String status) async {
    await client.rpc(
      'admin_hr_set_schedule_status',
      params: {'p_id': id, 'p_status': status},
    );
  }

  static String _day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static Map<String, dynamic> _asMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<Map<String, dynamic>> _rows(Object? value) => value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : const [];
}
