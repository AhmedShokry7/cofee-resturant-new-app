import 'package:equatable/equatable.dart';

/// دور الموظف، مرتبطًا بفرع محدد عندما يكون الدور فرعيًا.
class AdminRoleScope extends Equatable {
  const AdminRoleScope({
    required this.roleId,
    required this.roleCode,
    this.branchId,
  });

  final String roleId;
  final String roleCode;
  final String? branchId;

  @override
  List<Object?> get props => <Object?>[roleId, roleCode, branchId];
}
