import 'package:admin_app/features/staff/data/repositories/admin_staff_repository.dart';
import 'package:admin_app/features/staff/domain/repositories/staff_repository.dart';

/// نقطة تركيب اعتمادات فيتشر الموظفين داخل الفيتشر نفسه،
/// فلا تستورد طبقة العرض `data/repositories` مباشرة.
abstract final class StaffDependencies {
  StaffDependencies._();

  static StaffRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static StaffRepository get repository =>
      _repository ??= AdminStaffRepository();
}
