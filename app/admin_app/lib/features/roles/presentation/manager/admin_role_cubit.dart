import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/roles/data/repositories/admin_role_repository.dart';
import 'package:admin_app/features/roles/presentation/manager/admin_role_state.dart';

class AdminRoleCubit extends Cubit<AdminRoleState> {
  AdminRoleCubit({AdminRoleRepository? repository})
    : _repository = repository ?? AdminRoleRepository(),
      super(const AdminRoleState());

  final AdminRoleRepository _repository;

  AdminRoleRepository get repository => _repository;

  Future<void> load() async {
    emit(state.copyWith(status: AdminRoleStatus.loading, clearError: true));
    try {
      final roles = await _repository.loadRoles();
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

  Future<List<Map<String, dynamic>>> loadPermissions() =>
      _repository.loadPermissions();

  Future<void> setRolePermission(String roleId, String code, bool granted) =>
      _repository.setRolePermission(roleId, code, granted);
}
