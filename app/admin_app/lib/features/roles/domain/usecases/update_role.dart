import 'package:admin_app/features/roles/domain/repositories/role_repository.dart';

/// تحديث اسم الدور ووصفه وصلاحياته.
class UpdateRoleUseCase {
  const UpdateRoleUseCase(this._repository);

  final RoleRepository _repository;

  Future<void> call({
    required String roleId,
    required String nameAr,
    required String nameEn,
    required String description,
    required List<String> permissionCodes,
  }) => _repository.updateRole(
    roleId: roleId,
    nameAr: nameAr,
    nameEn: nameEn,
    description: description,
    permissionCodes: permissionCodes,
  );
}
