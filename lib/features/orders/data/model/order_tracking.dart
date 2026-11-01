import 'package:new_coffee/core/data/db_values.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/orders/data/model/tracking_step_model.dart';
import 'package:new_coffee/shared/utils/formatters.dart';

/// One row from `orders.order_status_history`.
class OrderStatusEvent {
  const OrderStatusEvent({
    this.fromStatus,
    required this.toStatus,
    this.note,
    this.changedAt,
  });

  final String? fromStatus;
  final String toStatus;
  final String? note;
  final DateTime? changedAt;

  factory OrderStatusEvent.fromDatabase(Map<String, dynamic> json) {
    final map = Db.asMap(json);
    final changedAt = Db.textOrNull(map['created_at']);
    return OrderStatusEvent(
      fromStatus: Db.textOrNull(map['from_status']),
      toStatus: Db.text(map['to_status']),
      note: Db.textOrNull(map['note']),
      changedAt: changedAt == null
          ? null
          : DateTime.tryParse(changedAt)?.toLocal(),
    );
  }
}

/// Builds the tracking timeline from real status history.
///
/// The old page showed four hardcoded steps with a fixed 2025 date for every
/// order. These steps follow the order's actual flow and use the timestamps
/// recorded by the server.
class OrderTrackingSteps {
  const OrderTrackingSteps._();

  static List<TrackingStepModel> forOrder({
    required String databaseStatus,
    required String fulfillmentType,
    required List<OrderStatusEvent> events,
    DateTime? placedAt,
  }) {
    final dates = <String, DateTime>{};
    for (final event in events) {
      final at = event.changedAt;
      if (at != null) dates[event.toStatus] = at;
    }
    String dateFor(String status, {DateTime? fallback}) {
      final at = dates[status] ?? fallback;
      return at == null ? '' : Formatters.date(at);
    }

    if (databaseStatus == 'cancelled') {
      return [
        TrackingStepModel(
          title: S.trackingOrderPlaced,
          date: dateFor('pending', fallback: placedAt),
          done: true,
        ),
        TrackingStepModel(
          title: S.orderCancelled,
          date: dateFor('cancelled'),
          done: true,
        ),
      ];
    }

    final flow = fulfillmentType == 'delivery'
        ? const [
            'pending',
            'confirmed',
            'preparing',
            'ready',
            'out_for_delivery',
            'completed',
          ]
        : const ['pending', 'confirmed', 'preparing', 'ready', 'completed'];
    final current = flow.indexOf(databaseStatus);
    final titles = {
      'pending': S.trackingOrderPlaced,
      'confirmed': S.trackingOrderConfirmed,
      'preparing': S.trackingPreparing,
      'ready': fulfillmentType == 'delivery'
          ? S.trackingReadyForDelivery
          : S.trackingReadyForPickup,
      'out_for_delivery': S.trackingOutForDelivery,
      'completed': S.trackingCompleted,
    };
    return [
      for (var i = 0; i < flow.length; i++)
        TrackingStepModel(
          title: titles[flow[i]]!,
          date: dateFor(
            flow[i],
            fallback: flow[i] == 'pending' ? placedAt : null,
          ),
          done: current < 0 ? i == 0 : i <= current,
        ),
    ];
  }
}
