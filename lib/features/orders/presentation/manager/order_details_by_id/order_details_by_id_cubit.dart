import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_copy.dart';
import 'package:new_coffee/features/orders/data/model/order_group.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';

part 'order_details_by_id_state.dart';

/// Reads the one order a notification named.
///
/// A notification carries an id and no rows of its own, while
/// [OrderDetailsPage] draws frozen invoice lines. So this asks the server for
/// the lines of that one id, and only a repository that cannot answer a lookup
/// by id falls back to scanning the recent history. The read is
/// owner-scoped on the server, which is what makes an id lifted from another
/// customer's notification come back as nothing rather than as someone else's
/// receipt.
class OrderDetailsByIdCubit extends Cubit<OrderDetailsByIdState> {
  OrderDetailsByIdCubit({required this._repository, required this.orderId})
    : super(const OrderDetailsByIdState()) {
    load();
  }

  final OrdersRepository _repository;
  final String orderId;

  /// The whole history the app reads when the repository cannot serve a lookup.
  ///
  /// [OrderLinesRepository] answers the named order in one scoped query; a
  /// repository without that capability is scanned instead, and a message that
  /// names an order older than this window is answered by the not-found state,
  /// which sends the customer to their list.
  static const int historyLimit = 500;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true, signedOut: false));
    try {
      final repository = _repository;
      final lines = switch (repository) {
        final OrderLinesRepository lookup => await lookup.orderLines(orderId),
        _ => await repository.listOrders(limit: historyLimit),
      };
      if (isClosed) return;
      OrderGroup? group;
      for (final candidate in OrderGroup.fromLines(lines)) {
        if (candidate.orderId == orderId) {
          group = candidate;
          break;
        }
      }
      emit(
        state.copyWith(order: group, notFound: group == null, isLoading: false),
      );
    } on OrderSignInRequiredException {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, signedOut: true));
    } catch (error, stackTrace) {
      if (isClosed) return;
      // The provider's own text is English and technical; what the screen needs
      // is a sentence and a retry, and the log keeps the real cause.
      emit(state.copyWith(isLoading: false, error: AppCopy.couldNotLoadOrders));
      addError(error, stackTrace);
    }
  }
}
