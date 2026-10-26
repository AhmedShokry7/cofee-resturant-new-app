import 'package:flutter/foundation.dart';
import 'package:admin_app/app_dependencies.dart';
import 'package:admin_app/core/customers/customer_details_reader.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/manager/admin_order_cubit.dart';

part 'admin_order_detail_loading.dart';
part 'admin_order_detail_actions.dart';
part 'admin_order_detail_values.dart';

class OrderDetailController extends ChangeNotifier {
  OrderDetailController({required this.cubit, required this.order});
  final AdminOrderCubit cubit;
  AdminOrder order;

  /// تفاصيل العميل تُقرأ عبر العقد الضيق، فلا يستورد الطلب فيتشر العملاء.
  final CustomerDetailsReader _customerRepository =
      AppDependencies.customerDetails;
  Map<String, dynamic>? customerDetails;
  bool customerDetailsLoading = false;
  bool customerDetailsFailed = false;
  bool orderSelectionLoading = false;
  bool saving = false;
  List<AdminProduct> products = const [];
  double? branchLatitude, branchLongitude;
  int _selectionRevision = 0;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
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
