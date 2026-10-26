import 'package:admin_app/core/catalog/branch_pricing_repository.dart';

class LoadBranchProductPricingUseCase {
  const LoadBranchProductPricingUseCase(this._repository);

  final BranchPricingRepository _repository;

  Future<List<Map<String, dynamic>>> call(String productId) =>
      _repository.loadBranchProductPricing(productId);
}
