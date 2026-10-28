import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_channel_slice.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_recent_order.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_sales_point.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_top_product.dart';
import 'package:admin_app/features/dashboard/domain/entities/dashboard_setup_step.dart';

/// أرقام لوحة التحكم كما ترجعها `admin_dashboard_metrics` (ترحيلة 203).
///
/// كل رقم هنا جمعته القاعدة من `orders.orders` للفروع التي يديرها القارئ، فالكيان
/// لا يعرف الشبكة ولا يحسب مجموعًا بدل القاعدة. الحقول التي قد تكون غائبة
/// (`monthlyRevenueTarget`, `newCustomers`) تبقى `null` معناها «الدالة لم ترسلها
/// لهذا الحساب»، وهو فرق مقصود عن صفر: الصفر رقم قرأته القاعدة، والغياب حجب.
class AdminDashboardMetrics {
  const AdminDashboardMetrics({
    this.todayOrders = 0,
    this.todayRevenue = 0,
    this.yesterdayOrders = 0,
    this.yesterdayRevenue = 0,
    this.averageOrderValue = 0,
    this.yesterdayAverageOrderValue = 0,
    this.activeOrders = 0,
    this.totalOrders = 0,
    this.weekOrders = 0,
    this.weekRevenue = 0,
    this.prevWeekOrders = 0,
    this.prevWeekRevenue = 0,
    this.monthOrders = 0,
    this.monthRevenue = 0,
    this.prevMonthOrders = 0,
    this.prevMonthRevenue = 0,
    this.monthlyRevenueTarget,
    this.totalCustomers,
    this.customersBeforeMonth,
    this.newCustomers,
    this.previousNewCustomers,
    this.salesSeries = const <AdminDashboardSalesPoint>[],
    this.channels = const <AdminDashboardChannelSlice>[],
    this.topProducts = const <AdminDashboardTopProduct>[],
    this.recentOrders = const <AdminDashboardRecentOrder>[],
    this.setupSteps = const <DashboardSetupStep>[],
  });

  static const empty = AdminDashboardMetrics();

  final int todayOrders;
  final double todayRevenue;
  final int yesterdayOrders;
  final double yesterdayRevenue;

  /// متوسط قيمة طلب اليوم، وتحسبه القاعدة حتى يبقى رقم واحد مصدره.
  final double averageOrderValue;
  final double yesterdayAverageOrderValue;

  /// الطلبات التي لم تكتمل ولم تُلغَ، عبر كل الأيام لا اليوم وحده.
  final int activeOrders;
  final int totalOrders;
  final int weekOrders;
  final double weekRevenue;
  final int prevWeekOrders;
  final double prevWeekRevenue;
  final int monthOrders;
  final double monthRevenue;

  /// الشهر الماضي بكامله، ويُرسل لأن نسبة النمو سؤال عن رقمين لا عن واحد:
  /// بلا أساس مكتوب تُطبع اللوحة قسمة على صفر أو تقديرًا من العرض.
  final int prevMonthOrders;
  final double prevMonthRevenue;

  /// هدف الشهر الذي كتبه المالك، و`null` حين لا هدف أو حين لا يدير القارئ كل
  /// الفروع: الهدف للشركة، وعرضه على مدير فرع واحد يجعله يظنّه هدف فرعه.
  final double? monthlyRevenueTarget;

  /// كل العملاء المسجَّين ومن كان منهم قبل الشهر الحالي، فيقول العدّاد رقمًا
  /// أمام مقارنته. ولا يصلان إلا لمن يملك `customers.read` ويدير كل الفروع.
  final int? totalCustomers;
  final int? customersBeforeMonth;

  /// عملاء جدد هذا الشهر والشهر السابق، ولا يصلان إلا لمن يملك `customers.read`
  /// ويدير كل الفروع.
  final int? newCustomers;
  final int? previousNewCustomers;

  final List<AdminDashboardSalesPoint> salesSeries;
  final List<AdminDashboardChannelSlice> channels;
  final List<AdminDashboardTopProduct> topProducts;
  final List<AdminDashboardRecentOrder> recentOrders;

  /// خطوات بداية المتجر التي تهمّ هذا القارئ وحده، وقد تكون أقل من أربع:
  /// خطوة لا يملك القارئ فعلها تُحذف من العدّاد، فلا يُلام على ناقص لا سلطة له.
  final List<DashboardSetupStep> setupSteps;

  /// هل قرأت القاعدة أي طلب لهذا النطاق؟ اللوحة الفارغة تعرض هذا السؤال.
  bool get hasAnyOrder => totalOrders > 0;
}
