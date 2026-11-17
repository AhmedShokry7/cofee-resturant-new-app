import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_service.dart';

abstract interface class HrAttendanceRepository {
  Future<List<Map<String, dynamic>>> loadBranches();

  Future<List<Map<String, dynamic>>> loadAttendance({
    required DateTime from,
    required DateTime to,
    String? branchId,
  });

  Future<List<Map<String, dynamic>>> loadCorrections();

  Future<void> reviewCorrection({
    required String correctionId,
    required bool approve,
    required String note,
  });
}

class SupabaseHrAttendanceRepository implements HrAttendanceRepository {
  SupabaseHrAttendanceRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? SupabaseService.client;

  @override
  Future<List<Map<String, dynamic>>> loadBranches() async {
    final result = await client.rpc('admin_hr_reference');
    final map = result is Map ? Map<String, dynamic>.from(result) : null;
    return _rows(map?['branches']);
  }

  @override
  Future<List<Map<String, dynamic>>> loadAttendance({
    required DateTime from,
    required DateTime to,
    String? branchId,
  }) async {
    final result = await client.rpc(
      'admin_hr_attendance',
      params: {
        'p_from': _date(from),
        'p_to': _date(to),
        'p_branch_id': branchId,
        'p_staff_id': null,
      },
    );
    return _rows(result);
  }

  @override
  Future<List<Map<String, dynamic>>> loadCorrections() async => _rows(
    await client.rpc(
      'admin_hr_attendance_corrections',
      params: {'p_status': 'pending'},
    ),
  );

  @override
  Future<void> reviewCorrection({
    required String correctionId,
    required bool approve,
    required String note,
  }) async {
    await client.rpc(
      'admin_hr_review_attendance_correction',
      params: {
        'p_correction_id': correctionId,
        'p_approve': approve,
        'p_note': note.trim().isEmpty ? null : note.trim(),
      },
    );
  }

  List<Map<String, dynamic>> _rows(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList(growable: false)
      : const [];

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
