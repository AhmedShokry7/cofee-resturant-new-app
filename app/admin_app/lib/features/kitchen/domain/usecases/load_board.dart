import 'package:admin_app/features/kitchen/domain/entities/admin_kitchen_ticket.dart';
import 'package:admin_app/features/kitchen/domain/repositories/kitchen_repository.dart';

/// قراءة تيكيتات سبورة المطبخ.
class LoadBoardUseCase {
  const LoadBoardUseCase(this._repository);

  final KitchenRepository _repository;

  Future<AdminKitchenBoard> call({
    String? search,
    String? branchId,
    int limit = 150,
  }) => _repository.loadBoard(search: search, branchId: branchId, limit: limit);
}
