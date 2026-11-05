import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

part 'order_cancellation_state.dart';

/// Cancels one order.
///
/// Customer cancellation is the only supported transition: other statuses are
/// moved by staff, stock, payment and fulfillment events on the server.
///
/// The tracking screen used to borrow [OrdersCubit] for this, but a pushed route
/// is built by the root navigator and never sits under the list's provider, so
/// the borrowed cubit was never there and every cancel ended as a failure
/// message. The write owns its own state instead.
class OrderCancellationCubit extends Cubit<OrderCancellationState> {
  OrderCancellationCubit({required this._repository, required this.orderId})
    : super(const OrderCancellationState());

  final OrdersRepository _repository;
  final String orderId;

  /// Cancels the order and reports whether the server took it.
  ///
  /// Returns the answer as well as putting it in the state, so the caller can
  /// close the screen only on a real cancellation instead of guessing from a
  /// rebuild.
  Future<bool> cancel({String? reason}) async {
    if (state.isCancelling) return false;
    emit(state.copyWith(isCancelling: true, clearError: true));
    try {
      await _repository.cancelOrder(orderId, reason: reason);
      if (isClosed) return false;
      emit(state.copyWith(isCancelling: false, cancelled: true));
      return true;
    } on OrderSignInRequiredException {
      if (isClosed) return false;
      emit(
        state.copyWith(isCancelling: false, error: AppCopy.signInToSeeOrders),
      );
      return false;
    } catch (error, stackTrace) {
      if (isClosed) return false;
      emit(
        state.copyWith(isCancelling: false, error: AppCopy.couldNotCancelOrder),
      );
      addError(error, stackTrace);
      return false;
    }
  }
}
