import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/core/models/dining_table.dart';

/// قراءة طاولات الفرع مع حالاتها الحيّة.
class LoadTablesUseCase {
  const LoadTablesUseCase(this._repository);

  final PosRepository _repository;

  Future<List<DiningTable>> call(String branchId) =>
      _repository.loadTables(branchId);
}
