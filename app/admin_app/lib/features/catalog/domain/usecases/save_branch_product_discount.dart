import 'package:admin_app/core/catalog/branch_pricing_repository.dart';

class SaveBranchProductDiscountUseCase {
  const SaveBranchProductDiscountUseCase(this._repository);

  final BranchPricingRepository _repository;

  Future<void> call({
    required String branchId,
    required String productId,
    double? discountPercentage,
    DateTime? discountStartsAt,
    DateTime? discountEndsAt,
    required bool useGeneralDiscount,
  }) => _repository.saveBranchProductDiscount(
    branchId: branchId,
    productId: productId,
    discountPercentage: discountPercentage,
    discountStartsAt: discountStartsAt,
    discountEndsAt: discountEndsAt,
    useGeneralDiscount: useGeneralDiscount,
  );
}
