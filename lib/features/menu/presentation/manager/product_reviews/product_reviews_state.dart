part of 'product_reviews_cubit.dart';

enum ProductReviewsStatus { loading, ready, failed }

class ProductReviewsState {
  const ProductReviewsState({
    this.status = ProductReviewsStatus.loading,
    this.summary = const ProductReviewSummary(),
    this.reviews = const <ProductReview>[],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final ProductReviewsStatus status;
  final ProductReviewSummary summary;
  final List<ProductReview> reviews;
  final bool hasMore;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  ProductReviewsState copyWith({
    ProductReviewsStatus? status,
    ProductReviewSummary? summary,
    List<ProductReview>? reviews,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return ProductReviewsState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      reviews: reviews ?? this.reviews,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}
