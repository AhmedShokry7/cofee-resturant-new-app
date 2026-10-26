import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/roles/di/roles_dependencies.dart';
import 'package:admin_app/features/roles/domain/repositories/role_repository.dart';
import 'package:admin_app/features/roles/domain/usecases/load_permissions.dart';
import 'package:admin_app/features/roles/domain/usecases/load_roles.dart';
import 'package:admin_app/features/roles/domain/usecases/set_role_permission.dart';
import 'package:admin_app/features/roles/presentation/manager/admin_role_state.dart';

class AdminRoleCubit extends Cubit<AdminRoleState> {
  AdminRoleCubit({RoleRepository? repository})
    : this._withUseCases(repository ?? RolesDependencies.repository);

  AdminRoleCubit._withUseCases(RoleRepository repository)
    : _loadRoles = LoadRolesUseCase(repository),
      _loadPermissions = LoadPermissionsUseCase(repository),
      _setRolePermission = SetRolePermissionUseCase(repository),
      super(const AdminRoleState());

  final LoadRolesUseCase _loadRoles;
  final LoadPermissionsUseCase _loadPermissions;
  final SetRolePermissionUseCase _setRolePermission;

  Future<void> load() async {
    emit(state.copyWith(status: AdminRoleStatus.loading, clearError: true));
    try {
      final roles = await _loadRoles();
      emit(
        state.copyWith(
          status: AdminRoleStatus.ready,
          roles: roles,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(status: AdminRoleStatus.failure, errorMessage: '$error'),
      );
    }
  }

  Future<List<Map<String, dynamic>>> loadPermissions() => _loadPermissions();

  Future<void> setRolePermission(String roleId, String code, bool granted) =>
      _setRolePermission(roleId, code, granted);
}
