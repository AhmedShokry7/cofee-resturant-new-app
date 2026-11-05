import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/features/orders/data/model/order_group.dart';
import 'package:new_coffee/features/orders/data/model/order_item_model.dart';
import 'package:new_coffee/features/orders/data/model/order_status.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

part 'orders_state.dart';

/// Loads the signed-in customer's real order history.
///
/// The old cubit started with five invented `OrderItemModel`s from the
/// compiled menu. History now comes from frozen invoice snapshots, so a later
/// price or product change cannot rewrite an old receipt.
class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({required this._repository})
    : super(const OrdersState(status: OrderStatus.active)) {
    load();
  }

  final OrdersRepository _repository;

  /// Counts the reads this cubit has started, so a response that arrives after a
  /// newer one was asked for is dropped instead of replacing it.
  ///
  /// Switching tabs fast used to leave the slower bucket's rows under the tab the
  /// customer is now looking at.
  int _generation = 0;

  Future<void> load() => _load(status: state.status);

  Future<void> refresh() => _load(status: state.status);

  Future<void> selectStatus(OrderStatus status) {
    if (status == state.status && !state.isLoading) return Future.value();
    return _load(status: status);
  }

  Future<void> _load({required OrderStatus status}) async {
    final generation = ++_generation;
    // A tab change is a different question, so the old rows are dropped with it;
    // a refresh of the same tab keeps them on screen while the answer comes.
    final keepRows = status == state.status;
    emit(
      state.copyWith(
        status: status,
        orders: keepRows ? null : const [],
        isLoading: true,
        clearError: true,
        signedOut: false,
      ),
    );
    try {
      final orders = await _repository.listOrders(status: status);
      if (isClosed || generation != _generation) return;
      emit(state.copyWith(status: status, orders: orders, isLoading: false));
    } on OrderSignInRequiredException {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: status,
          orders: const [],
          isLoading: false,
          signedOut: true,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed || generation != _generation) return;
      // The provider's text is English and technical, and the list has a retry to
      // offer, so the state carries the sentence the customer reads.
      emit(
        state.copyWith(
          status: status,
          orders: const [],
          isLoading: false,
          error: AppCopy.couldNotLoadOrders,
        ),
      );
      addError(error, stackTrace);
    }
  }
}
