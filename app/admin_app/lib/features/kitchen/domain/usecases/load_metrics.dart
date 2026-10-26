import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_metrics.dart';
import 'package:admin_app/features/kitchen/domain/repositories/kitchen_repository.dart';

/// قراءة ملخص مؤشرات المطبخ.
class LoadMetricsUseCase {
  const LoadMetricsUseCase(this._repository);

  final KitchenRepository _repository;

  Future<AdminKitchenMetrics> call({String? branchId}) =>
      _repository.loadMetrics(branchId: branchId);
}
