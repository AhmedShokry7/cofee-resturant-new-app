import 'package:admin_app/features/dashboard/data/models/admin_dashboard_json.dart';
import 'package:admin_app/features/dashboard/data/models/admin_dashboard_rows.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';

/// تحويل استجابة `admin_dashboard_metrics` إلى كيان اللوحة.
///
/// كل حقل ناقص يصير صفرًا أو قائمة فارغة، والحقول التي تعني «محجوب» تُبقى
/// `null` (`monthly_revenue_target`, `new_customers`): القاعدة لا ترسلها لمن لا
/// يملك نطاقها، فتحويلها إلى صفر يجعل اللوحة تقول «صفر عملاء» بدل أن تصمت.
/// وترتيب الصفوف كما وصل منها: هي رتّبت الحالة بتدفقها والمنتجات بحجمها.
class AdminDashboardMetricsModel {
  const AdminDashboardMetricsModel._();

  static AdminDashboardMetrics fromJson(Map<String, dynamic> json) {
    return AdminDashboardMetrics(
      todayOrders: AdminDashboardJson.integer(json['today_orders']),
      todayRevenue: AdminDashboardJson.decimal(json['today_revenue']),
      yesterdayOrders: AdminDashboardJson.integer(json['yesterday_orders']),
      yesterdayRevenue: AdminDashboardJson.decimal(json['yesterday_revenue']),
      averageOrderValue: AdminDashboardJson.decimal(
        json['average_order_value'],
      ),
      yesterdayAverageOrderValue: AdminDashboardJson.decimal(
        json['yesterday_average_order_value'],
      ),
      activeOrders: AdminDashboardJson.integer(json['active_orders']),
      totalOrders: AdminDashboardJson.integer(json['total_orders']),
      weekOrders: AdminDashboardJson.integer(json['week_orders']),
      weekRevenue: AdminDashboardJson.decimal(json['week_revenue']),
      prevWeekOrders: AdminDashboardJson.integer(json['prev_week_orders']),
      prevWeekRevenue: AdminDashboardJson.decimal(json['prev_week_revenue']),
      monthOrders: AdminDashboardJson.integer(json['month_orders']),
      monthRevenue: AdminDashboardJson.decimal(json['month_revenue']),
      prevMonthOrders: AdminDashboardJson.integer(json['prev_month_orders']),
      prevMonthRevenue: AdminDashboardJson.decimal(json['prev_month_revenue']),
      monthlyRevenueTarget: AdminDashboardJson.nullableDecimal(
        json['monthly_revenue_target'],
      ),
      totalCustomers: AdminDashboardJson.nullableInteger(
        json['total_customers'],
      ),
      customersBeforeMonth: AdminDashboardJson.nullableInteger(
        json['customers_before_month'],
      ),
      newCustomers: AdminDashboardJson.nullableInteger(json['new_customers']),
      previousNewCustomers: AdminDashboardJson.nullableInteger(
        json['previous_new_customers'],
      ),
      salesSeries: AdminDashboardJson.rows(
        json['sales_series'],
        AdminDashboardRows.sale,
      ),
      channels: AdminDashboardJson.rows(
        json['channels'],
        AdminDashboardRows.channel,
      ),
      topProducts: AdminDashboardJson.rows(
        json['top_products'],
        AdminDashboardRows.product,
      ),
      recentOrders: AdminDashboardJson.rows(
        json['recent_orders'],
        AdminDashboardRows.recent,
      ),
      setupSteps: AdminDashboardJson.rows(
        json['setup_steps'],
        AdminDashboardRows.setup,
      ),
    );
  }
}
