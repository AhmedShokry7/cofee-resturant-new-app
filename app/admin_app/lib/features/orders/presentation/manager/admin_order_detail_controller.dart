import 'package:flutter/foundation.dart';

import 'package:admin_app/features/catalog/data/models/admin_product.dart';
import 'package:admin_app/features/customers/data/repositories/admin_customer_repository.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_cubit.dart';

/// The editable view of one order: the order itself, its lines and the
/// products the dashboard holds.
///
/// The page listens to it and redraws; every write goes through the cubit of
/// the orders, so no widget touches the repository.
class OrderDetailController extends ChangeNotifier {
  OrderDetailController({required this.cubit, required this.order});

  /// The cubit of the orders every write goes through.
  final AdminOrderCubit cubit;

  /// The customer repository, reused for the customer details of this order.
  final AdminCustomerRepository _customerRepository = AdminCustomerRepository();

  /// The order the page shows, replaced after every write.
  AdminOrder order;

  /// The details of the customer behind this order, when loaded.
  Map<String, dynamic>? customerDetails;

  /// True while the customer details are being fetched.
  bool customerDetailsLoading = false;

  /// The products of the dashboard, loaded once so the admin may add one.
  List<AdminProduct> products = const <AdminProduct>[];

  /// Coordinates of the branch that owns the order, when available.
  double? branchLatitude;
  double? branchLongitude;
  /// True while the status of the order is being written.
  bool saving = false;

  /// Loads the products of the dashboard.
  Future<void> loadProducts() async {
    try {
      final snapshot = await cubit.loadCatalog();
      products = snapshot.products;
      notifyListeners();
    } catch (_) {}
    _syncBranchCoordinates();
    await loadCustomerDetails();
  }

  /// Loads the customer details (including previous orders) for this order.
  Future<void> loadCustomerDetails() async {
    final id = order.userId?.trim();
    if (id == null || id.isEmpty) return;
    customerDetailsLoading = true;
    notifyListeners();
    try {
      customerDetails = await _customerRepository.loadCustomerDetails(id);
    } catch (_) {
      customerDetails = null;
    } finally {
      customerDetailsLoading = false;
      notifyListeners();
    }
  }

  void _syncBranchCoordinates() {
    branchLatitude = order.branchLatitude;
    branchLongitude = order.branchLongitude;
    notifyListeners();
  }

  /// Reads the order again after a write, so its lines and total stay right.
  Future<void> reload() async {
    try {
      final updated = await cubit.findOrder(order.id);
      if (updated == null) return;
      order = updated;
      _syncBranchCoordinates();
    } catch (_) {}
  }

  /// Changes the status of the order and reads it back.
  Future<void> changeStatus(String status) async {
    saving = true;
    notifyListeners();
    try {
      await cubit.updateOrderStatus(order.id, status);
      order = order.copyWith(status: status);
      notifyListeners();
      await reload();
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  /// Changes the payment status of the order and reads it back.
  Future<void> changePaymentStatus(String paymentStatus) async {
    saving = true;
    notifyListeners();
    try {
      await cubit.updatePaymentStatus(order.id, paymentStatus);
      order = order.copyWith(paymentStatus: paymentStatus);
      notifyListeners();
      await reload();
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  /// Adds a product line to the order.
  Future<void> addProduct(AdminProduct product, int quantity) async {
    await cubit.addOrderItem(order.id, product.id, quantity);
    await reload();
  }

  /// Removes one line of the order.
  Future<void> removeItem(String itemId) async {
    await cubit.removeOrderItem(itemId);
    await reload();
  }

  /// The latitude of the delivery address, when the order has one.
  double? get deliveryLatitude {
    final addr = order.deliveryAddressSnapshot;
    if (addr == null) return null;
    return (addr['latitude'] as num?)?.toDouble() ??
        (addr['lat'] as num?)?.toDouble();
  }

  /// The longitude of the delivery address, when the order has one.
  double? get deliveryLongitude {
    final addr = order.deliveryAddressSnapshot;
    if (addr == null) return null;
    return (addr['longitude'] as num?)?.toDouble() ??
        (addr['lng'] as num?)?.toDouble();
  }
}
