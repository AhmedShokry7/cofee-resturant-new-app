import 'package:admin_app/core/catalog/branch_pricing_repository.dart';

class LoadBranchesUseCase {
  const LoadBranchesUseCase(this._repository);

  final BranchPricingRepository _repository;

  Future<List<Map<String, dynamic>>> call() => _repository.loadBranches();
}
