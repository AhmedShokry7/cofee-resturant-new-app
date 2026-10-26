import 'package:equatable/equatable.dart';

import 'package:admin_app/features/auth/domain/entities/admin_permission_scope.dart';
import 'package:admin_app/features/auth/domain/entities/admin_role_scope.dart';

/// جلسة الموظف المسجّل: هويته وأدواره وصلاحياته.
///
/// كيان المجال لا يعرف شكل الـ JSON ولا Supabase؛ التحويل يتم في طبقة البيانات.
class AdminSession extends Equatable {
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

  /// المالك يملك كل الصلاحيات بلا استثناء.
  bool get isOwner => roles.any((role) => role.roleCode == 'owner');

  /// كل أكواد الصلاحيات الممنوحة، مجمّعة من كل الفروع.
  Set<String> get permissions => <String>{
    for (final scope in permissionScopes) ...scope.permissions,
  };

  /// هل يملك الموظف كود الصلاحية المطلوب؟
  bool hasPermission(String code) => isOwner || permissions.contains(code);

  @override
  List<Object?> get props => <Object?>[
    staffId,
    fullName,
    email,
    status,
    roles,
    permissionScopes,
    canManageAllBranches,
  ];
}
