part of 'admin_order_detail_controller.dart';

extension OrderDetailLoading on OrderDetailController {
  Future<void> loadProducts() async {
    final customerTask = loadCustomerDetails();
    try {
      final snapshot = await cubit.loadCatalog();
      if (_disposed) return;
      products = snapshot.products;
      productsFailed = false;
    } catch (_) {
      // قراءة فاشلة تُعلَّم، فالقائمة الفارغة وحدها تُقرأ كأن الفرع بلا منتجات.
      productsFailed = true;
    }
    _syncBranchCoordinates();
    await customerTask;
  }

  Future<void> loadCustomerDetails() async {
    final revision = _selectionRevision;
    final id = order.userId?.trim();
    if (id == null || id.isEmpty) {
      customerDetails = null;
      customerDetailsFailed = false;
      customerDetailsLoading = false;
      _notify();
      return;
    }
    customerDetailsLoading = true;
    customerDetailsFailed = false;
    _notify();
    try {
      final details = await _customerRepository.loadCustomerDetails(id);
      if (revision == _selectionRevision) customerDetails = details;
    } catch (_) {
      if (revision == _selectionRevision) {
        customerDetails = null;
        customerDetailsFailed = true;
      }
    } finally {
      if (revision == _selectionRevision) {
        customerDetailsLoading = false;
        _notify();
      }
    }
  }
}
