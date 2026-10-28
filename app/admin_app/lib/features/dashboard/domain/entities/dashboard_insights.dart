import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_metrics.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_sales_point.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_top_product.dart';

/// الحسابات التي تُبنى من رقمين قرأتهما القاعدة، ولا تحسب رقمًا جديدًا مكانها.
///
/// الفرق بين «قيمة مشتقة» و«رقم مخترع» أن كل ما هنا قسمة أو نسبة بين حقلين
/// وصلين من نفس الاستجابة: تقدّم نحو هدف، وحصة منتج. أما أي مجموع أو مقارنة
/// زمنية فمكانه القاعدة، لأن العرض لا يرى بقية الصفوف — ونسبة التغيّر بين
/// رقمين لها موضع واحد تطبعه اللوحات كلها: `metricPercentTrend`.
extension DashboardInsights on AdminDashboardMetrics {
  bool get hasMonthlyTarget => (monthlyRevenueTarget ?? 0) > 0;

  /// نسبة ما تحقق من هدف الشهر بين ٠ و١، و`null` حين لا هدف.
  ///
  /// تُقصّ عند ١ لأن الشريط لا يتجاوز نهايته؛ المبلغ نفسه يُطبع كاملًا فوقه.
  double? get targetProgress {
    if (!hasMonthlyTarget) return null;
    return (monthRevenue / monthlyRevenueTarget!).clamp(0.0, 1.0);
  }

  /// حصة منتج من إيراد الأسبوع، لحساب النسبة التي تُطبع بجانب اسمه.
  double topProductShare(AdminDashboardTopProduct product) =>
      weekRevenue <= 0 ? 0 : (product.revenue / weekRevenue).clamp(0.0, 1.0);

  /// نافذة العرض من السلسلة الكاملة: آخر [days] يومًا بالسابق فالأحدث.
  ///
  /// المدى الذي يراه الأدمن قرار عرض، لكن جمعه يبقى هنا حتى تُقارن نافذتان
  /// بنفس الطريقة في أي شاشة تستعمل السلسلة نفسها.
  List<AdminDashboardSalesPoint> salesWindow(int days) =>
      salesSeries.length <= days
      ? salesSeries
      : salesSeries.sublist(salesSeries.length - days);

  /// مال النافذة المعروضة، مجموعًا من أيامها لا من رقم ترسله القاعدة لها.
  double revenueWindow(int days) =>
      salesWindow(days).fold(0.0, (sum, day) => sum + day.revenue);

  /// عدد طلبات النافذة المعروضة.
  int ordersWindow(int days) =>
      salesWindow(days).fold(0, (sum, day) => sum + day.orders);

  /// أغزر يوم مالًا في النافذة المعروضة، و`null` حين لا مال فيها أصلًا.
  ///
  /// اختيار الأقصى من أيام أرسلتها القاعدة كاملة، لا تقدير رقم مكانها: اليوم
  /// نفسه وتاريخه حقيقيان، والمقارنة بينهما قسمة لا جديد.
  AdminDashboardSalesPoint? peakSalesDay(int days) {
    AdminDashboardSalesPoint? peak;
    for (final day in salesWindow(days)) {
      if (day.revenue <= 0) continue;
      if (peak == null || day.revenue > peak.revenue) peak = day;
    }
    return peak;
  }

  /// حصة جزء من مجموعة، كقناة من إيراد المدى.
  double shareOf(num part, num total) =>
      total <= 0 ? 0 : (part / total).clamp(0.0, 1.0);

  /// إجمالي إيراد القنوات كما وصلت، وهو مقام نسب الدونات.
  ///
  /// القاعدة تجمع كل قناة على حدة ولا ترسل المجموع؛ هذا جمع قائمة صغيرة وصلت
  /// كاملة، لا جمع على جدول لا يراه العرض.
  double get channelRevenueTotal =>
      channels.fold(0.0, (sum, slice) => sum + slice.revenue);

  /// أعلى يوم مالًا في النافذة، وهو سقف المحور الرأسي.
  ///
  /// السقف من أكبر ما أرسلته القاعدة لا من تقدير مريح للعين: محورٌ يسع دائمًا
  /// أكثر مما حدث يجعل القمة تبدو منتصف اللوحة.
  double peakSalesValue(int days) {
    var top = 0.0;
    for (final day in salesWindow(days)) {
      if (day.revenue > top) top = day.revenue;
    }
    return top;
  }
}
