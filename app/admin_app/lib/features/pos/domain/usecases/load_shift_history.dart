import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/domain/entities/pos_shift.dart';

/// قراءة صفحة من تاريخ ورديات الفرع.
class LoadShiftHistoryUseCase {
  const LoadShiftHistoryUseCase(this._repository);

  final PosRepository _repository;

  Future<List<PosShift>> call(
    String branchId, {
    int limit = 20,
    int offset = 0,
  }) => _repository.loadShiftHistory(branchId, limit: limit, offset: offset);
}
