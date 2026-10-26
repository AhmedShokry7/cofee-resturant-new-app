import 'package:admin_app/features/roles/data/models/admin_role.dart';
import 'package:admin_app/features/roles/domain/repositories/role_repository.dart';

/// قراءة كل الأدوار.
class LoadRolesUseCase {
  const LoadRolesUseCase(this._repository);

  final RoleRepository _repository;

  Future<List<AdminRole>> call() => _repository.loadRoles();
}
