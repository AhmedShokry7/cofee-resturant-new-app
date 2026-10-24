import 'package:admin_app/features/roles/data/models/admin_role.dart';

enum AdminRoleStatus { initial, loading, ready, failure }

class AdminRoleState {
  const AdminRoleState({
    this.status = AdminRoleStatus.initial,
    this.roles = const <AdminRole>[],
    this.errorMessage,
  });

  final AdminRoleStatus status;
  final List<AdminRole> roles;
  final String? errorMessage;

  bool get isLoading => status == AdminRoleStatus.loading;
  bool get hasRoles => roles.isNotEmpty;

  AdminRoleState copyWith({
    AdminRoleStatus? status,
    List<AdminRole>? roles,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminRoleState(
      status: status ?? this.status,
      roles: roles ?? this.roles,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
