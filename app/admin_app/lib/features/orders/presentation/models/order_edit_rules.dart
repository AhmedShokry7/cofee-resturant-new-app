import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/core/models/order_status_codes.dart';

/// When the dashboard may add or remove the items of an order.
///
/// The rules mirror what the backend enforces today:
///
/// * `admin_add_order_item` and `admin_remove_order_item` recompute the
///   subtotal and the grand total on the server, and they refuse anyone
///   without `orders.status.update`.
/// * Since `154_admin_order_item_guards.sql` they also refuse a closed order
///   or a refunded one, so the dashboard refuses the same orders here and
///   never offers an action the server will reject.
/// * Since `200_admin_order_item_stock_and_delivery_fee.sql` an add also needs
///   the branch to hold the units, and the delivery fee follows the zone at the
///   new subtotal. Neither is knowable from the order row, so the dashboard does
///   not pre-empt it: it shows the database's own refusal.
class OrderEditRules {
  const OrderEditRules._();

  /// True when the items of the order may still be changed.
  static bool canEditItems(AdminOrder order) {
    if (OrderStatusCodes.closed.contains(order.status)) return false;
    if (order.paymentStatus == 'refunded') return false;
    return true;
  }

  /// True when one item can be removed: the order is editable and the
  /// backend returned the identifier the removal RPC needs.
  ///
  /// `admin_orders` only returns item ids from `176_admin_pos_customers.sql`
  /// onward, so a database that has not replayed that migration keeps the
  /// action disabled; the dashboard never fakes a removal.
  static bool canRemoveItem(AdminOrder order, {required bool hasItemId}) {
    return canEditItems(order) && hasItemId;
  }
}
