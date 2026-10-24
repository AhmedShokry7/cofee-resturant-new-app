import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/roles/data/models/admin_role.dart';

class AdminRoleRepository {
  AdminRoleRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  Future<List<AdminRole>> loadRoles() async {
    final response = await _supabase.rpc('admin_roles');
    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => AdminRole.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }
    return const <AdminRole>[];
  }

  Future<List<Map<String, dynamic>>> loadPermissions() async {
    final response = await _supabase.rpc('admin_permissions');
    if (response is List) {
      return response
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  Future<void> setRolePermission(
    String roleId,
    String code,
    bool granted,
  ) async {
    await _supabase.rpc(
      'admin_set_role_permission',
      params: {
        'p_role_id': roleId,
        'p_permission_code': code,
        'p_granted': granted,
      },
    );
  }
}
