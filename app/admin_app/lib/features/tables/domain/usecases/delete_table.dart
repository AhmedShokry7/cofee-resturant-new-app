import 'package:admin_app/features/tables/domain/repositories/dining_table_repository.dart';

/// حذف طاولة من الصالة.
class DeleteTableUseCase {
  const DeleteTableUseCase(this._repository);

  final DiningTableRepository _repository;

  Future<DiningTableMutationOutcome> call(String tableId) =>
      _repository.deleteTable(tableId);
}
