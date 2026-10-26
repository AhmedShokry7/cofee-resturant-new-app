import 'package:admin_app/features/roles/domain/repositories/role_repository.dart';

/// قراءة كتالوج الصلاحيات كصفوف خام.
class LoadPermissionsUseCase {
  const LoadPermissionsUseCase(this._repository);

  final RoleRepository _repository;

  Future<List<Map<String, dynamic>>> call() => _repository.loadPermissions();
}
