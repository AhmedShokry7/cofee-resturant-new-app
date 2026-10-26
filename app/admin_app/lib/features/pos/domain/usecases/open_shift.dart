import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/domain/entities/pos_shift.dart';

/// فتح وردية الصندوق برصيد افتتاحي.
class OpenShiftUseCase {
  const OpenShiftUseCase(this._repository);

  final PosRepository _repository;

  Future<PosShift> call({
    required String branchId,
    required double openingFloat,
    String? note,
  }) => _repository.openShift(
    branchId: branchId,
    openingFloat: openingFloat,
    note: note,
  );
}
