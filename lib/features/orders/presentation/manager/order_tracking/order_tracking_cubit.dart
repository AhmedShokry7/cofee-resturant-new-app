import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/orders/data/model/order_tracking.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

part 'order_tracking_state.dart';

/// Reads the status history of one order for the tracking screen.
///
/// The page used to keep the `Future<List<OrderStatusEvent>>` in its own state
/// and hand it to a `FutureBuilder`, which put a repository call inside a
/// widget and left a failed read with no way to retry.
class OrderTrackingCubit extends Cubit<OrderTrackingState> {
  OrderTrackingCubit({
    required OrdersRepository repository,
    required String orderId,
  })  : _repository = repository,
        _orderId = orderId,
        super(const OrderTrackingState());

  final OrdersRepository _repository;
  final String _orderId;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearEvents: true));
    try {
      final events = await _repository.orderHistory(_orderId);
      if (isClosed) return;
      emit(state.copyWith(events: events, isLoading: false, failed: false));
    } catch (_) {
      if (isClosed) return;
      // The provider's text is English and technical, and the screen has a
      // retry to offer, so the state only records that the read failed.
      emit(state.copyWith(isLoading: false, failed: true));
    }
  }
}
