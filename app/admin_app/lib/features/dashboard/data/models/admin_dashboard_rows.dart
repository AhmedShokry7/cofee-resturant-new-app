import 'package:admin_app/features/dashboard/data/models/admin_dashboard_json.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_channel_slice.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_recent_order.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_sales_point.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_top_product.dart';
import 'package:admin_app/features/dashboard/domain/entities/dashboard_setup_step.dart';

/// بناء أسطر لوحات اللوحة من صف `jsonb` واحد.
///
/// السطر الذي يحتاج تاريخًا صالحًا ليقال شيء (`sales_series`, `recent_orders`)
/// يرجع `null` فيُسقَط من اللوحة: لا يوم بلا تاريخ ولا طلب بلا وقت. أما بقية
/// الصفوف فالحقول الناقصة فيها أصفار، لأن القاعدة أرسلتها مفرّغة لا محجوبة.
class AdminDashboardRows {
  const AdminDashboardRows._();

  static AdminDashboardSalesPoint? sale(Map<String, dynamic> row) {
    final date = AdminDashboardJson.date(row['date']);
    if (date == null) return null;
    return AdminDashboardSalesPoint(
      date: date,
      revenue: AdminDashboardJson.decimal(row['revenue']),
      orders: AdminDashboardJson.integer(row['orders']),
    );
  }

  static AdminDashboardChannelSlice channel(Map<String, dynamic> row) {
    return AdminDashboardChannelSlice(
      channel: AdminDashboardJson.text(row['channel']),
      orders: AdminDashboardJson.integer(row['orders']),
      revenue: AdminDashboardJson.decimal(row['revenue']),
    );
  }

  static AdminDashboardTopProduct product(Map<String, dynamic> row) {
    return AdminDashboardTopProduct(
      nameAr: AdminDashboardJson.text(row['product_name_ar']),
      nameEn: AdminDashboardJson.text(row['product_name_en']),
      quantity: AdminDashboardJson.integer(row['quantity']),
      revenue: AdminDashboardJson.decimal(row['revenue']),
      imageUrl: AdminDashboardJson.nullableText(row['image_url']),
    );
  }

  static DashboardSetupStep setup(Map<String, dynamic> row) {
    return DashboardSetupStep(
      key: AdminDashboardJson.text(row['key']),
      done: AdminDashboardJson.boolean(row['done']),
    );
  }

  static AdminDashboardRecentOrder? recent(Map<String, dynamic> row) {
    final placedAt = AdminDashboardJson.date(row['placed_at']);
    if (placedAt == null) return null;
    return AdminDashboardRecentOrder(
      id: AdminDashboardJson.text(row['id']),
      orderNumber: AdminDashboardJson.text(row['order_number']),
      status: AdminDashboardJson.text(row['status']),
      fulfillmentType: AdminDashboardJson.text(row['fulfillment_type']),
      grandTotal: AdminDashboardJson.decimal(row['grand_total']),
      itemsCount: AdminDashboardJson.integer(row['items_count']),
      placedAt: placedAt,
      customerName: AdminDashboardJson.nullableText(row['customer_name']),
    );
  }
}
