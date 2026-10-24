class AdminStaffRole {
  const AdminStaffRole({
    required this.roleId,
    required this.roleCode,
    this.branchId,
  });

  final String roleId;
  final String roleCode;
  final String? branchId;

  factory AdminStaffRole.fromJson(Map<String, dynamic> json) {
    return AdminStaffRole(
      roleId: '${json['role_id'] ?? ''}',
      roleCode: '${json['role_code'] ?? ''}',
      branchId: json['branch_id'] as String?,
    );
  }
}

class AdminStaffMember {
  const AdminStaffMember({
    required this.id,
    required this.userId,
    this.fullName,
    this.email,
    required this.status,
    this.createdAt,
    this.acceptedAt,
    this.roles = const <AdminStaffRole>[],
    this.permissions = const <String>[],
  });

  final String id;
  final String userId;
  final String? fullName;
  final String? email;
  final String status;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final List<AdminStaffRole> roles;
  final List<String> permissions;

  String displayName() {
    if (fullName != null && fullName!.trim().isNotEmpty) {
      return fullName!.trim();
    }
    if (email != null && email!.trim().isNotEmpty) {
      return email!.trim();
    }
    return id;
  }

  factory AdminStaffMember.fromJson(Map<String, dynamic> json) {
    final rolesRaw = json['roles'] as List<dynamic>?;
    final permsRaw = json['permissions'] as List<dynamic>?;
    return AdminStaffMember(
      id: '${json['id'] ?? ''}',
      userId: '${json['user_id'] ?? ''}',
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      status: '${json['status'] ?? ''}',
      createdAt: _toDateTime(json['created_at']),
      acceptedAt: _toDateTime(json['accepted_at']),
      roles:
          rolesRaw
              ?.map(
                (e) => AdminStaffRole.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const <AdminStaffRole>[],
      permissions: permsRaw?.map((e) => '$e').toList() ?? const <String>[],
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}