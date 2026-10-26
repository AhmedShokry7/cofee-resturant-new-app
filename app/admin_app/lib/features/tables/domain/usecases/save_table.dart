import 'package:admin_app/features/tables/domain/repositories/dining_table_repository.dart';
import 'package:admin_app/features/tables/domain/entities/dining_table_draft.dart';

/// حفظ طاولة جديدة أو تعديل طاولة قائمة.
class SaveTableUseCase {
  const SaveTableUseCase(this._repository);

  final DiningTableRepository _repository;

  Future<DiningTableSaveOutcome> call(DiningTableDraft draft) =>
      _repository.saveTable(draft);
}
