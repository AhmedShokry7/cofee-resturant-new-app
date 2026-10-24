import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';

enum AdminOrderStatus { initial, loading, ready, failure }

class AdminOrderState {
  const AdminOrderState({
    this.status = AdminOrderStatus.initial,
    this.orders = const <AdminOrder>[],
    this.branches = const <AdminBranch>[],
    this.errorMessage,
  });

  final AdminOrderStatus status;
  final List<AdminOrder> orders;
  final List<AdminBranch> branches;
  final String? errorMessage;

  bool get isLoading => status == AdminOrderStatus.loading;
  bool get hasOrders => orders.isNotEmpty;

  AdminOrderState copyWith({
    AdminOrderStatus? status,
    List<AdminOrder>? orders,
    List<AdminBranch>? branches,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminOrderState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      branches: branches ?? this.branches,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
