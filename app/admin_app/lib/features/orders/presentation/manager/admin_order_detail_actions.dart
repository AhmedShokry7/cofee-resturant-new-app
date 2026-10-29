part of 'admin_order_detail_controller.dart';

extension OrderDetailActions on OrderDetailController {
  /// Re-reads this order from the server, never from the directory cache.
  ///
  /// `findOrder` answers from the Cubit's rows first, and those rows can be
  /// older than a write that just landed: the live feed reads them too, and
  /// whichever read started first may be the one that emits last. A screen that
  /// shows what the admin just edited has to ask the database itself.
  Future<void> reload() async {
    final orderId = order.id;
    final revision = _selectionRevision;
    try {
      final rows = await cubit.loadOrders();
      if (revision != _selectionRevision || order.id != orderId) return;
      final updated = rows.where((row) => row.id == orderId);
      if (updated.isEmpty) return;
      order = updated.first;
      _syncBranchCoordinates();
    } catch (_) {}
  }

  /// Moves the order forward and then shows what the backend stored.
  ///
  /// The write itself belongs to the Cubit: it locks the directory against a
  /// second tap and reloads the rows. The local copy changes only once that
  /// write was accepted, so a dropped or refused status never leaves the header
  /// showing a state the order does not have.
  Future<bool> changeStatus(String status) async {
    final orderId = order.id;
    final revision = _selectionRevision;
    final applied = await cubit.updateOrderStatus(orderId, status);
    if (!applied) return false;
    if (revision != _selectionRevision || order.id != orderId) return true;
    order = order.copyWith(status: status);
    _notify();
    await reload();
    return true;
  }

  Future<bool> changePaymentStatus(String status) async {
    final orderId = order.id;
    final revision = _selectionRevision;
    final applied = await cubit.updatePaymentStatus(orderId, status);
    if (!applied) return false;
    if (revision != _selectionRevision || order.id != orderId) return true;
    order = order.copyWith(paymentStatus: status);
    _notify();
    await reload();
    return true;
  }

  Future<bool> addProduct(AdminProduct product, int quantity) async {
    final orderId = order.id;
    final revision = _selectionRevision;
    final applied = await cubit.addOrderItem(orderId, product.id, quantity);
    if (!applied) return false;
    if (revision != _selectionRevision || order.id != orderId) return true;
    await reload();
    return true;
  }

  Future<bool> removeItem(String itemId) async {
    final orderId = order.id;
    final revision = _selectionRevision;
    final applied = await cubit.removeOrderItem(itemId);
    if (!applied) return false;
    if (revision != _selectionRevision || order.id != orderId) return true;
    await reload();
    return true;
  }
}
