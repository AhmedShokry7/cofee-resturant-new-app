import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';

/// قراءة كتالوج الصلاحيات كصفوف خام.
class LoadPermissionsUseCase {
  const LoadPermissionsUseCase(this._repository);

  final StaffRepository _repository;

  Future<List<Map<String, dynamic>>> call() => _repository.loadPermissions();
}
