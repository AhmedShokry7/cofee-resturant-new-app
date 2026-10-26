/// أسعار المنتج لكل فرع وخصوماته.
abstract interface class BranchPricingRepository {
  Future<List<Map<String, dynamic>>> loadBranches();

  Future<List<Map<String, dynamic>>> loadBranchProductPricing(String productId);

  Future<void> saveBranchProductDiscount({
    required String branchId,
    required String productId,
    double? discountPercentage,
    DateTime? discountStartsAt,
    DateTime? discountEndsAt,
    required bool useGeneralDiscount,
  });
}
