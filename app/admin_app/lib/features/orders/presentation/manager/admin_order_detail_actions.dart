part of 'admin_order_detail_controller.dart';

extension OrderDetailActions on OrderDetailController {
  Future<void> reload() async {
    final revision = _selectionRevision;
    try {
      final updated = await cubit.findOrder(order.id);
      if (updated == null || revision != _selectionRevision) return;
      order = updated;
      _syncBranchCoordinates();
    } catch (_) {}
  }

  Future<void> changeStatus(String status) async {
    final orderId = order.id;
    final revision = _selectionRevision;
    saving = true;
    _notify();
    try {
      await cubit.updateOrderStatus(orderId, status);
      if (revision != _selectionRevision || order.id != orderId) return;
      order = order.copyWith(status: status);
      _notify();
      await reload();
    } finally {
      if (revision == _selectionRevision) {
        saving = false;
        _notify();
      }
    }
  }

  Future<void> changePaymentStatus(String status) async {
    final orderId = order.id;
    final revision = _selectionRevision;
    saving = true;
    _notify();
    try {
      await cubit.updatePaymentStatus(orderId, status);
      if (revision != _selectionRevision || order.id != orderId) return;
      order = order.copyWith(paymentStatus: status);
      _notify();
      await reload();
    } finally {
      if (revision == _selectionRevision) {
        saving = false;
        _notify();
      }
    }
  }

  Future<void> addProduct(AdminProduct product, int quantity) async {
    final orderId = order.id;
    final revision = _selectionRevision;
    await cubit.addOrderItem(orderId, product.id, quantity);
    if (revision == _selectionRevision && order.id == orderId) await reload();
  }

  Future<void> removeItem(String itemId) async {
    final orderId = order.id;
    final revision = _selectionRevision;
    await cubit.removeOrderItem(itemId);
    if (revision == _selectionRevision && order.id == orderId) await reload();
  }
}
