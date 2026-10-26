import 'package:admin_app/features/tables/domain/repositories/dining_table_repository.dart';

/// تغيير حالة الحجز في القاعدة.
class SetReservationStatusUseCase {
  const SetReservationStatusUseCase(this._repository);

  final DiningTableRepository _repository;

  Future<DiningReservationStatusOutcome> call(
    String reservationId,
    String status,
  ) => _repository.setReservationStatus(reservationId, status);
}
