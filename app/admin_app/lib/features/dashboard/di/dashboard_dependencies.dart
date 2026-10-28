import 'package:admin_app/features/dashboard/data/repositories/admin_dashboard_repository.dart';
import 'package:admin_app/features/dashboard/domain/repositories/dashboard_repository.dart';

/// نقطة تركيب اعتمادات لوحة التحكم داخل الفيتشر نفسه، فلا تستورد طبقة العرض
/// `data/repositories` مباشرة.
abstract final class DashboardDependencies {
  DashboardDependencies._();

  static DashboardRepository? _repository;

  /// نسخة مشتركة من العقد تُبنى عند أول استخدام.
  static DashboardRepository get repository =>
      _repository ??= AdminDashboardRepository();
}
