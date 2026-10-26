import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_metrics.dart';

class AdminAuditRepository {
  AdminAuditRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  Future<AdminAuditPage> loadPage({
    String? search,
    String? domain,
    bool criticalOnly = false,
    int page = 0,
    int pageSize = 20,
  }) async {
    final response = await _supabase.rpc(
      'admin_audit_directory',
      params: {
        'p_search': _blankToNull(search),
        'p_domain': _blankToNull(domain),
        'p_critical_only': criticalOnly,
        'p_limit': pageSize,
        'p_offset': page * pageSize,
      },
    );
    if (response is Map) {
      return AdminAuditPage.fromJson(Map<String, dynamic>.from(response));
    }
    return const AdminAuditPage();
  }

  Future<AdminAuditMetrics> loadMetrics() async {
    final response = await _supabase.rpc('admin_audit_metrics');
    if (response is Map) {
      return AdminAuditMetrics.fromJson(Map<String, dynamic>.from(response));
    }
    return AdminAuditMetrics.empty;
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
