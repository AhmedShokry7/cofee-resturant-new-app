import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

abstract interface class HrSettingsRepository {
  Future<Map<String, dynamic>> load();
  Future<void> save({
    required String timeZone,
    required int graceMinutes,
    double? lateRate,
    double? earlyRate,
    double? absenceRate,
    required bool cashierDeductions,
    double? deductionCap,
    double? unpaidLeaveRate,
  });
}

class SupabaseHrSettingsRepository implements HrSettingsRepository {
  SupabaseHrSettingsRepository({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? SupabaseService.client;

  @override
  Future<Map<String, dynamic>> load() async {
    final raw = await client.rpc('admin_hr_reference');
    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    return map['settings'] is Map
        ? Map<String, dynamic>.from(map['settings'] as Map)
        : <String, dynamic>{};
  }

  @override
  Future<void> save({
    required String timeZone,
    required int graceMinutes,
    double? lateRate,
    double? earlyRate,
    double? absenceRate,
    required bool cashierDeductions,
    double? deductionCap,
    double? unpaidLeaveRate,
  }) async {
    await client.rpc(
      'admin_hr_update_settings',
      params: {
        'p_business_time_zone': timeZone.trim(),
        'p_late_grace_minutes': graceMinutes,
        'p_late_minute_rate': lateRate,
        'p_early_minute_rate': earlyRate,
        'p_absence_day_rate': absenceRate,
        'p_cashier_deduction_allowed': cashierDeductions,
        'p_max_salary_deduction_percent': deductionCap,
        'p_unpaid_leave_day_rate': unpaidLeaveRate,
      },
    );
  }
}
