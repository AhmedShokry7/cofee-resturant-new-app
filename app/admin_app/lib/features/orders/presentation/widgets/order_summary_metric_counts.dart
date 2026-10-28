import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/core/models/order_status_codes.dart';

class OrderSummaryMetricCounts {
  static bool inRange(AdminOrder order, DateTime from, DateTime to) =>
      order.placedAt != null &&
      !order.placedAt!.isBefore(from) &&
      order.placedAt!.isBefore(to);

  static double paid(Iterable<AdminOrder> orders) => orders
      .where((order) => order.paymentStatus == 'paid')
      .fold<double>(0, (sum, order) => sum + order.grandTotal);

  static int shipped(Iterable<AdminOrder> orders) => orders
      .where((order) => order.status == OrderStatusCodes.outForDelivery)
      .length;

  static int awaiting(Iterable<AdminOrder> orders) =>
      orders.where(_awaiting).length;

  static int newToday(Iterable<AdminOrder> orders, DateTime now) => orders
      .where(_awaiting)
      .where((order) => _isToday(order.placedAt?.toLocal(), now))
      .length;

  static bool _awaiting(AdminOrder order) => const {
    OrderStatusCodes.pending,
    OrderStatusCodes.confirmed,
  }.contains(order.status);

  static bool _isToday(DateTime? placed, DateTime now) =>
      placed != null &&
      placed.year == now.year &&
      placed.month == now.month &&
      placed.day == now.day;
}
