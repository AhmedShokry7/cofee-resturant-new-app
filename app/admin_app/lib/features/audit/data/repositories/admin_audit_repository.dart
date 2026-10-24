import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';

class AdminAuditRepository {
  AdminAuditRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  Future<List<AdminAuditLog>> loadLogs({int limit = 200}) async {
    final response = await _supabase.rpc(
      'admin_audit_log',
      params: {'p_limit': limit},
    );
    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => AdminAuditLog.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }
    return const <AdminAuditLog>[];
  }
}
