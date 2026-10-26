import 'package:admin_app/features/orders/domain/entities/admin_order.dart';

/// When the dashboard may add or remove the items of an order.
///
/// The rules follow what the backend enforces today:
///
/// * `admin_add_order_item` and `admin_remove_order_item` recompute the
///   subtotal and the grand total on the server, and they refuse anyone
///   without `orders.status.update`.
/// * They do not check the status of the order, so the dashboard must not
///   offer the action for orders whose history must stay untouched.
///
/// Completed, cancelled and refunded orders are therefore read only here.
/// A missing backend guard for them is documented in the final report.
class OrderEditRules {
  const OrderEditRules._();

  /// True when the items of the order may still be changed.
  static bool canEditItems(AdminOrder order) {
    if (order.status == 'completed' || order.status == 'cancelled') {
      return false;
    }
    if (order.paymentStatus == 'refunded') return false;
    return true;
  }

  /// True when one item can be removed: the order is editable and the
  /// backend returned the identifier the removal RPC needs.
  ///
  /// The current `admin_orders` RPC does not return the id of the items, so
  /// the action stays disabled until the RPC exposes it; the dashboard never
  /// fakes a removal.
  static bool canRemoveItem(AdminOrder order, {required bool hasItemId}) {
    return canEditItems(order) && hasItemId;
  }
}
