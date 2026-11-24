import 'package:admin_app/features/roles/domain/repositories/role_repository.dart';

/// إنشاء دور مخصّص بصلاحياته المختارة.
class CreateRoleUseCase {
  const CreateRoleUseCase(this._repository);

  final RoleRepository _repository;

  Future<String> call({
    required String nameAr,
    required String nameEn,
    required String description,
    required List<String> permissionCodes,
  }) => _repository.createRole(
    nameAr: nameAr,
    nameEn: nameEn,
    description: description,
    permissionCodes: permissionCodes,
  );
}
