import 'package:admin_app/features/pos/domain/entities/pos_cashier.dart';
import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';

/// قراءة موظفي الفرع الذين تصلح لهم وردية الصندوق.
class LoadCashiersUseCase {
  const LoadCashiersUseCase(this._repository);

  final PosRepository _repository;

  Future<List<PosCashier>> call(String branchId) =>
      _repository.loadCashiers(branchId);
}
