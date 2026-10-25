import 'package:admin_app/features/orders/data/models/admin_order.dart';

class OrderSummaryMetricCounts {
  static bool inRange(AdminOrder order, DateTime from, DateTime to) =>
      order.placedAt != null &&
      !order.placedAt!.isBefore(from) &&
      order.placedAt!.isBefore(to);

  static double paid(Iterable<AdminOrder> orders) => orders
      .where((order) => order.paymentStatus == 'paid')
      .fold<double>(0, (sum, order) => sum + order.grandTotal);

  static int shipped(Iterable<AdminOrder> orders) =>
      orders.where((order) => order.status == 'out_for_delivery').length;

  static int awaiting(Iterable<AdminOrder> orders) => orders
      .where((order) => const {'pending', 'confirmed'}.contains(order.status))
      .length;

  static int newToday(Iterable<AdminOrder> orders, DateTime now) =>
      orders.where((order) {
        final placed = order.placedAt?.toLocal();
        return placed != null &&
            placed.year == now.year &&
            placed.month == now.month &&
            placed.day == now.day &&
            const {'pending', 'confirmed'}.contains(order.status);
      }).length;
}
