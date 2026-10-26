import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/domain/entities/pos_shift.dart';

/// إغلاق الوردية بعد عدّ الصندوق.
class CloseShiftUseCase {
  const CloseShiftUseCase(this._repository);

  final PosRepository _repository;

  Future<PosShift> call({
    required String shiftId,
    required double countedCash,
    String? closeNote,
  }) => _repository.closeShift(
    shiftId: shiftId,
    countedCash: countedCash,
    closeNote: closeNote,
  );
}
