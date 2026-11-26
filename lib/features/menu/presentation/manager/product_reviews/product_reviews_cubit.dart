import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/menu/data/model/product_review.dart';
import 'package:new_coffee/features/menu/data/repositories/product_reviews_repository.dart';

part 'product_reviews_state.dart';

/// Loads the review summary and the newest page of reviews for one product,
/// then appends older pages on demand.
class ProductReviewsCubit extends Cubit<ProductReviewsState> {
  ProductReviewsCubit({
    required this._repository,
    required this.productId,
    this.pageSize = 5,
  }) : super(const ProductReviewsState()) {
    load();
  }

  final ProductReviewsRepository _repository;
  final String productId;
  final int pageSize;

  Future<void> load() async {
    emit(const ProductReviewsState());
    try {
      final summary = await _repository.getSummary(productId);
      final page = await _repository.getReviews(productId, limit: pageSize);
      emit(
        ProductReviewsState(
          status: ProductReviewsStatus.ready,
          summary: summary,
          reviews: page,
          hasMore: page.length == pageSize,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(const ProductReviewsState(status: ProductReviewsStatus.failed));
    }
  }

  Future<void> loadMore() async {
    if (state.status != ProductReviewsStatus.ready ||
        state.isLoadingMore ||
        !state.hasMore) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true, loadMoreFailed: false));
    try {
      final page = await _repository.getReviews(
        productId,
        limit: pageSize,
        offset: state.reviews.length,
      );
      final known = {for (final review in state.reviews) review.id};
      final fresh = page.where((review) => !known.contains(review.id));
      emit(
        state.copyWith(
          reviews: [...state.reviews, ...fresh],
          hasMore: page.length == pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(isLoadingMore: false, loadMoreFailed: true));
    }
  }
}
