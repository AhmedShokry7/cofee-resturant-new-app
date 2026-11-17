import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

abstract interface class HrDashboardRepository {
  Future<Map<String, dynamic>> load({String? branchId});
}

class SupabaseHrDashboardRepository implements HrDashboardRepository {
  SupabaseHrDashboardRepository({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? SupabaseService.client;

  @override
  Future<Map<String, dynamic>> load({String? branchId}) async {
    final results = await Future.wait<Object?>([
      client.rpc('admin_hr_dashboard', params: {'p_branch_id': branchId}),
      client.rpc('admin_hr_reference'),
    ]);
    final dashboard = _map(results.first);
    final reference = _map(results.last);
    return {...dashboard, '_branches': _rows(reference['branches'])};
  }

  Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  List<Map<String, dynamic>> _rows(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList(growable: false)
      : const [];
}
