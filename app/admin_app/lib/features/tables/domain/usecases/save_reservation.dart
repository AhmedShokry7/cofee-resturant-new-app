import 'package:admin_app/features/tables/domain/repositories/dining_table_repository.dart';
import 'package:admin_app/features/tables/domain/entities/dining_reservation_draft.dart';

/// حفظ حجز جديد أو تعديل حجز قائم.
class SaveReservationUseCase {
  const SaveReservationUseCase(this._repository);

  final DiningTableRepository _repository;

  Future<DiningReservationSaveOutcome> call(DiningReservationDraft draft) =>
      _repository.saveReservation(draft);
}
