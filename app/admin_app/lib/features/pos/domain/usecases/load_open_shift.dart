import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/domain/entities/pos_shift.dart';

/// قراءة وردية الفرع المفتوحة.
class LoadOpenShiftUseCase {
  const LoadOpenShiftUseCase(this._repository);

  final PosRepository _repository;

  Future<PosShift?> call(String branchId) =>
      _repository.loadOpenShift(branchId);
}
