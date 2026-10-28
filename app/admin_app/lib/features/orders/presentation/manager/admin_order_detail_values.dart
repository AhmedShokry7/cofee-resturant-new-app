part of 'admin_order_detail_controller.dart';

extension OrderDetailValues on OrderDetailController {
  List<AdminOrder> get previousOrders {
    final id = order.userId;
    if (id == null) return const [];
    final results = cubit.state.orders
        .where(
          (candidate) => candidate.userId == id && candidate.id != order.id,
        )
        .toList();
    results.sort(
      (a, b) =>
          (b.placedAt ?? DateTime(0)).compareTo(a.placedAt ?? DateTime(0)),
    );
    return results;
  }

  Future<bool> openOrder(String id) async {
    final revision = ++_selectionRevision;
    orderSelectionLoading = true;
    _notify();
    try {
      final selected = await cubit.findOrder(id);
      if (revision != _selectionRevision || selected == null) return false;
      order = selected;
      customerDetails = null;
      customerDetailsFailed = false;
      _syncBranchCoordinates();
      await loadCustomerDetails();
      return revision == _selectionRevision;
    } finally {
      if (revision == _selectionRevision) {
        orderSelectionLoading = false;
        _notify();
      }
    }
  }

  double? get deliveryLatitude => _coordinate('latitude', 'lat');
  double? get deliveryLongitude => _coordinate('longitude', 'lng');
  double? _coordinate(String key, String fallback) {
    final address = order.deliveryAddressSnapshot;
    return (address?[key] as num?)?.toDouble() ??
        (address?[fallback] as num?)?.toDouble();
  }
}
