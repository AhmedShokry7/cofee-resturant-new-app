import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_filters.dart';
import 'package:admin_app/features/kitchen/domain/repositories/kitchen_repository.dart';

/// قراءة خيارات فروع المطبخ.
class LoadFiltersUseCase {
  const LoadFiltersUseCase(this._repository);

  final KitchenRepository _repository;

  Future<AdminKitchenFilters> call() => _repository.loadFilters();
}
