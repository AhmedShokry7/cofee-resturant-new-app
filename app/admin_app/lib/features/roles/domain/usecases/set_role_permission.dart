import 'package:admin_app/features/roles/domain/repositories/role_repository.dart';

/// منح صلاحية لوظيفة أو سحبها.
class SetRolePermissionUseCase {
  const SetRolePermissionUseCase(this._repository);

  final RoleRepository _repository;

  Future<void> call(String roleId, String code, bool granted) =>
      _repository.setRolePermission(roleId, code, granted);
}
