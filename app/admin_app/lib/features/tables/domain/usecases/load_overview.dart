import 'package:admin_app/features/tables/domain/repositories/dining_table_repository.dart';
import 'package:admin_app/features/tables/domain/entities/dining_overview.dart';

/// قراءة نظرة الفرع على الطاولات والحجوزات.
class LoadOverviewUseCase {
  const LoadOverviewUseCase(this._repository);

  final DiningTableRepository _repository;

  Future<DiningOverview> call({String? branchId}) =>
      _repository.loadOverview(branchId: branchId);
}
