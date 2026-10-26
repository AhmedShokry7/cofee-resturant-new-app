import 'dart:convert';

import 'package:admin_app/core/auth/admin_permission_scope.dart';
import 'package:admin_app/core/auth/admin_role_scope.dart';
import 'package:admin_app/core/auth/admin_session.dart';

/// يحوّل رد دالة `admin_get_my_staff_record` إلى كيان [AdminSession].
///
/// هذا هو المكان الوحيد الذي يعرف شكل الـ JSON؛ المجال يبقى نقيًا.
class AdminSessionModel {
  const AdminSessionModel(this._json);

  final Map<String, dynamic> _json;

  /// يقبل خريطة أو نص JSON، لأن رد PostgREST قد يأتي بأي من الشكلين.
  factory AdminSessionModel.fromRpc(dynamic raw) {
    if (raw is Map) {
      return AdminSessionModel(Map<String, dynamic>.from(raw));
    }
    if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AdminSessionModel(Map<String, dynamic>.from(decoded));
      }
    }
    throw const FormatException('Unexpected staff record response.');
  }

  /// يبني كيان الجلسة من الحقول المقروءة.
  AdminSession toEntity() {
    return AdminSession(
      staffId: '${_json['staff_id'] ?? ''}',
      fullName: '${_json['full_name'] ?? ''}',
      email: '${_json['email'] ?? ''}',
      status: '${_json['status'] ?? ''}',
      roles: _mapList(_json['roles'])
          .map(
            (role) => AdminRoleScope(
              roleId: '${role['role_id'] ?? ''}',
              roleCode: '${role['role_code'] ?? ''}',
              branchId: role['branch_id'] as String?,
            ),
          )
          .toList(),
      permissionScopes: _mapList(_json['permissions'])
          .map(
            (scope) => AdminPermissionScope(
              branchId: scope['branch_id'] as String?,
              permissions: scope['permissions'] is List
                  ? (scope['permissions'] as List)
                        .map((code) => '$code')
                        .toList()
                  : const <String>[],
            ),
          )
          .toList(),
      canManageAllBranches: _json['can_manage_all_branches'] == true,
    );
  }

  /// يحوّل أي قائمة خرائط إلى قائمة آمنة، ويتجاهل العناصر غير الصالحة.
  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }
}
