import 'package:new_coffee/features/menu/data/model/product_review.dart';

abstract class ProductReviewsRepository {
  Future<ProductReviewSummary> getSummary(String productId);

  /// Published reviews for [productId], newest first.
  Future<List<ProductReview>> getReviews(
    String productId, {
    int limit = 5,
    int offset = 0,
  });
}

/// Used when no backend is ready (preview builds). Shows no reviews rather
/// than inventing any.
class UnavailableProductReviewsRepository implements ProductReviewsRepository {
  const UnavailableProductReviewsRepository();

  @override
  Future<ProductReviewSummary> getSummary(String productId) async =>
      const ProductReviewSummary();

  @override
  Future<List<ProductReview>> getReviews(
    String productId, {
    int limit = 5,
    int offset = 0,
  }) async => const <ProductReview>[];
}
