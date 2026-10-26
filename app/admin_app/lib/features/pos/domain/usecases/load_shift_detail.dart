import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/domain/entities/pos_shift.dart';

/// قراءة تقرير وردية واحدة.
class LoadShiftDetailUseCase {
  const LoadShiftDetailUseCase(this._repository);

  final PosRepository _repository;

  Future<PosShift> call(String shiftId) => _repository.loadShiftDetail(shiftId);
}
