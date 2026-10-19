import 'dart:convert';

class AdminRoleScope {
  const AdminRoleScope({
    required this.roleId,
    required this.roleCode,
    this.branchId,
  });

  final String roleId;
  final String roleCode;
  final String? branchId;

  factory AdminRoleScope.fromJson(Map<String, dynamic> json) {
    return AdminRoleScope(
      roleId: '${json['role_id'] ?? ''}',
      roleCode: '${json['role_code'] ?? ''}',
      branchId: json['branch_id'] as String?,
    );
  }
}

class AdminPermissionScope {
  const AdminPermissionScope({
    this.branchId,
    required this.permissions,
  });

  final String? branchId;
  final List<String> permissions;

  factory AdminPermissionScope.fromJson(Map<String, dynamic> json) {
    final raw = json['permissions'];
    final codes = raw is List ? raw.map((e) => '$e').toList() : const <String>[];
    return AdminPermissionScope(
      branchId: json['branch_id'] as String?,
      permissions: codes,
    );
  }
}

class AdminSession {
  const AdminSession({
    required this.staffId,
    required this.fullName,
    required this.email,
    required this.status,
    required this.roles,
    required this.permissionScopes,
    required this.canManageAllBranches,
  });

  final String staffId;
  final String fullName;
  final String email;
  final String status;
  final List<AdminRoleScope> roles;
  final List<AdminPermissionScope> permissionScopes;
  final bool canManageAllBranches;

  bool get isOwner => roles.any((role) => role.roleCode == 'owner');

  Set<String> get permissions => <String>{
        for (final scope in permissionScopes) ...scope.permissions,
      };

  bool hasPermission(String code) => isOwner || permissions.contains(code);

  factory AdminSession.fromJson(Map<String, dynamic> json) {
    return AdminSession(
      staffId: '${json['staff_id'] ?? ''}',
      fullName: '${json['full_name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      status: '${json['status'] ?? ''}',
      roles: _mapList(json['roles']).map(AdminRoleScope.fromJson).toList(),
      permissionScopes:
          _mapList(json['permissions']).map(AdminPermissionScope.fromJson).toList(),
      canManageAllBranches: json['can_manage_all_branches'] == true,
    );
  }

  factory AdminSession.fromRpc(dynamic raw) {
    if (raw is Map) {
      return AdminSession.fromJson(Map<String, dynamic>.from(raw));
    }
    if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AdminSession.fromJson(Map<String, dynamic>.from(decoded));
      }
    }
    throw const FormatException('Unexpected staff record response.');
  }

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
