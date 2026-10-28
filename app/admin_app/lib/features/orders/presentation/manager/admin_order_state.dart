import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/domain/entities/order_status_rules.dart';

enum AdminOrderStatus { initial, loading, ready, failure }

class AdminOrderState {
  const AdminOrderState({
    this.status = AdminOrderStatus.initial,
    this.orders = const <AdminOrder>[],
    this.branches = const <AdminBranch>[],
    this.saving = false,
    this.statusRules,
    this.errorMessage,
  });

  final AdminOrderStatus status;
  final List<AdminOrder> orders;
  final List<AdminBranch> branches;

  /// True while one write (status, payment, an item) is on its way to the
  /// backend, so a second tap cannot send the same mutation twice.
  final bool saving;

  /// The transitions the database allows this staff member. Null until
  /// `loadStatusRules()` returns, so a control can tell "not read yet" apart
  /// from "this order is closed".
  final OrderStatusRules? statusRules;

  final String? errorMessage;

  bool get isLoading => status == AdminOrderStatus.loading;
  bool get hasOrders => orders.isNotEmpty;

  AdminOrderState copyWith({
    AdminOrderStatus? status,
    List<AdminOrder>? orders,
    List<AdminBranch>? branches,
    bool? saving,
    OrderStatusRules? statusRules,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminOrderState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      branches: branches ?? this.branches,
      saving: saving ?? this.saving,
      statusRules: statusRules ?? this.statusRules,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
