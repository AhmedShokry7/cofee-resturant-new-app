import 'package:admin_app/features/roles/data/repositories/admin_role_repository.dart';
import 'package:admin_app/features/roles/domain/repositories/role_repository.dart';

/// نقطة تركيب اعتمادات فيتشر الأدوار داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class RolesDependencies {
  RolesDependencies._();

  static RoleRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static RoleRepository get repository => _repository ??= AdminRoleRepository();
}
