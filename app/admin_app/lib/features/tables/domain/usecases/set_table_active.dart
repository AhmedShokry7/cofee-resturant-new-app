import 'package:admin_app/features/tables/domain/repositories/dining_table_repository.dart';

/// تفعيل الطاولة أو تعطيلها.
class SetTableActiveUseCase {
  const SetTableActiveUseCase(this._repository);

  final DiningTableRepository _repository;

  Future<DiningTableMutationOutcome> call(String tableId, bool active) =>
      _repository.setTableActive(tableId, active);
}
