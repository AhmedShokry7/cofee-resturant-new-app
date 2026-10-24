import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';

class AdminStaffRepository {
  AdminStaffRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  Future<List<AdminStaffMember>> loadStaff() async {
    final response = await _supabase.rpc('admin_staff');
    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (row) => AdminStaffMember.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    }
    return const <AdminStaffMember>[];
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

  Future<void> setStaffPermission(
    String staffId,
    String permissionCode,
    bool granted,
  ) async {
    await _supabase.rpc(
      'admin_set_staff_permission',
      params: {
        'p_staff_id': staffId,
        'p_permission_code': permissionCode,
        'p_granted': granted,
      },
    );
  }
}
