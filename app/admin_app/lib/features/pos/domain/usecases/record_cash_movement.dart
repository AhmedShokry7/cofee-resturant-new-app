import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/domain/entities/pos_shift.dart';

/// تسجيل حركة نقد داخل الوردية.
class RecordCashMovementUseCase {
  const RecordCashMovementUseCase(this._repository);

  final PosRepository _repository;

  Future<PosShift> call({
    required String shiftId,
    required PosCashMovementKind kind,
    required double amount,
    required String reason,
  }) => _repository.recordCashMovement(
    shiftId: shiftId,
    kind: kind,
    amount: amount,
    reason: reason,
  );
}
