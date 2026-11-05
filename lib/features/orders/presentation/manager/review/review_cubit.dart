import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

part 'review_state.dart';

/// Sends the customer's rating of one product.
///
/// The review screen used to pop the route and show "review submitted" without
/// writing anything: the rating and the sentence were read from widgets that no
/// call ever asked for. The server holds a row per customer and product, so this
/// is the write that makes the confirmation true.
class ReviewCubit extends Cubit<ReviewState> {
  ReviewCubit({required this._repository}) : super(const ReviewState());

  final OrdersRepository _repository;

  /// Stores the rating, and says whether the server took it.
  ///
  /// A repository that cannot write reviews — the offline fallback — is answered
  /// with the failure rather than a silent success.
  Future<bool> submit({
    required String productId,
    String? orderId,
    required int rating,
    String? body,
  }) async {
    if (state.isSubmitting) return false;
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final reviewer = switch (_repository) {
        final ReviewRepository reviewer => reviewer,
        _ => throw UnsupportedError('Reviews need the order backend.'),
      };
      await reviewer.submitReview(
        productId: productId,
        orderId: orderId,
        rating: rating,
        body: body,
      );
      if (isClosed) return false;
      emit(state.copyWith(isSubmitting: false, submitted: true));
      return true;
    } on OrderSignInRequiredException {
      if (isClosed) return false;
      emit(
        state.copyWith(isSubmitting: false, error: AppCopy.signInToSeeOrders),
      );
      return false;
    } catch (error, stackTrace) {
      if (isClosed) return false;
      emit(
        state.copyWith(isSubmitting: false, error: AppCopy.reviewSubmitFailed),
      );
      addError(error, stackTrace);
      return false;
    }
  }
}
