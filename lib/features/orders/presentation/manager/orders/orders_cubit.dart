import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  OrdersCubit({required OrdersRepository repository})
      : _repository = repository,
        super(const OrdersState(status: OrderStatus.active)) {
    load();
  }

  final OrdersRepository _repository;

  Future<void> load() => _load(status: state.status);

  Future<void> refresh() => _load(status: state.status);

  Future<void> selectStatus(OrderStatus status) {
    if (status == state.status && !state.isLoading) return Future.value();
    return _load(status: status);
  }

  Future<void> _load({required OrderStatus status}) async {
    emit(state.copyWith(
      status: status,
      isLoading: true,
      clearError: true,
      signedOut: false,
    ));
    try {
      final orders = await _repository.listOrders(status: status);
      if (isClosed) return;
      emit(state.copyWith(
        status: status,
        orders: orders,
        isLoading: false,
      ));
    } on OrderSignInRequiredException {
      if (isClosed) return;
      emit(state.copyWith(
        status: status,
        orders: const [],
        isLoading: false,
        signedOut: true,
      ));
    } catch (error, stackTrace) {
      if (isClosed) return;
      emit(state.copyWith(
        status: status,
        isLoading: false,
        error: error.toString(),
      ));
      addError(error, stackTrace);
    }
  }

  /// Cancels one order through the backend and reloads history.
  ///
  /// Customer cancellation is the only supported transition: other statuses are
  /// moved by staff, stock, payment and fulfillment events on the server.
  Future<void> cancelOrder(OrderItemModel order, {String? reason}) async {
    final orderId = order.orderId.isNotEmpty ? order.orderId : order.id;
    await _repository.cancelOrder(orderId, reason: reason);
    await refresh();
  }
}
