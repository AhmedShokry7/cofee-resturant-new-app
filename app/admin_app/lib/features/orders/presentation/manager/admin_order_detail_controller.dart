import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:admin_app/app_dependencies.dart';
import 'package:admin_app/core/customers/customer_details_reader.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/domain/entities/order_status_rules.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_cubit.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_state.dart';

part 'admin_order_detail_loading.dart';
part 'admin_order_detail_actions.dart';
part 'admin_order_detail_values.dart';

class OrderDetailController extends ChangeNotifier {
  /// The visitor may write when their role carries `orders.status.update`,
  /// which is exactly the permission every order mutation RPC demands. Without
  /// it the screen is a read-only view instead of a set of buttons that fail.
  OrderDetailController({
    required this.cubit,
    required this.order,
    this.canManage = true,
  }) {
    // One screen, one Cubit: the page listens to this controller, so the
    // Cubit's own writes are forwarded here rather than duplicated.
    _cubitSubscription = cubit.stream.listen((_) => _notify());
  }
  final AdminOrderCubit cubit;
  final bool canManage;
  AdminOrder order;

  /// تفاصيل العميل تُقرأ عبر العقد الضيق، فلا يستورد الطلب فيتشر العملاء.
  final CustomerDetailsReader _customerRepository =
      AppDependencies.customerDetails;
  Map<String, dynamic>? customerDetails;
  bool customerDetailsLoading = false;
  bool customerDetailsFailed = false;
  bool orderSelectionLoading = false;

  /// The Cubit owns the one-write-at-a-time lock; the screen only reads it.
  bool get saving => cubit.state.saving;

  /// الانتقالات المسموحة، أو `null` قبل قراءتها. انظر `AdminOrderCubit.loadStatusRules`.
  OrderStatusRules? get statusRules => cubit.state.statusRules;
  List<AdminProduct> products = const [];
  double? branchLatitude, branchLongitude;
  int _selectionRevision = 0;
  bool _disposed = false;
  StreamSubscription<AdminOrderState>? _cubitSubscription;

  @override
  void dispose() {
    _disposed = true;
    unawaited(_cubitSubscription?.cancel());
    _cubitSubscription = null;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _syncBranchCoordinates() {
    branchLatitude = order.branchLatitude;
    branchLongitude = order.branchLongitude;
    _notify();
  }
}
