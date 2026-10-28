import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/fulfillment_type.dart';
import 'package:admin_app/core/models/order_status.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_recent_order.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_top_product.dart';
import 'package:admin_app/features/dashboard/presentation/utils/dashboard_display.dart';

/// ما يتركه نصّ البحث في ترويسة اللوحة من أسطر.
///
/// البحث معروضٌ خالص: لا يُسأل عنه شيء في القاعدة، فلا معنى لرقم جديد ولا
/// لقراءة أخرى. والمقارنة تنزل على الاسم بالعربي والإنجليزي والرمز الخام
/// معًا، فيكتب الأدمن `latte` أو `قهوة` أو `completed` أو `مكتمل` ويصيب.
class DashboardVisibleRows {
  const DashboardVisibleRows(this.metrics, this.query);

  final AdminDashboardMetrics metrics;
  final String query;

  bool get _isEmpty => query.trim().isEmpty;

  String _lower(String value) => value.trim().toLowerCase();

  /// سبب الفراغ يبقى مذكورًا بنصَّين مختلفين: لا عمل بعد، أو البحث لم يُبقِ.
  String get emptyMessage =>
      _isEmpty ? S.noOrdersYet : S.dashboardNothingMatches;

  List<AdminDashboardTopProduct> get products {
    if (_isEmpty) return metrics.topProducts;
    final needle = _lower(query);
    return metrics.topProducts
        .where(
          (product) =>
              _lower(product.nameAr).contains(needle) ||
              _lower(product.nameEn).contains(needle) ||
              _lower(dashboardProductName(product)).contains(needle),
        )
        .toList(growable: false);
  }

  List<AdminDashboardRecentOrder> get orders {
    if (_isEmpty) return metrics.recentOrders;
    final needle = _lower(query);
    return metrics.recentOrders
        .where((order) {
          final view = OrderStatusView.of(order.status);
          return _lower(order.orderNumber).contains(needle) ||
              _lower(order.customerName ?? '').contains(needle) ||
              _lower(view.label).contains(needle) ||
              _lower(fulfillmentLabel(order.fulfillmentType)).contains(needle);
        })
        .toList(growable: false);
  }
}
