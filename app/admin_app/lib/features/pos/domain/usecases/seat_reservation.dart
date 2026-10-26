import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';

/// تسجيل جلوس ضيف الحجز في الطاولة.
class SeatReservationUseCase {
  const SeatReservationUseCase(this._repository);

  final PosRepository _repository;

  Future<PosSeatOutcome> call(String reservationId) =>
      _repository.seatReservation(reservationId);
}
